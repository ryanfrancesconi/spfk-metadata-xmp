// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#include "XMPLifecycleCXX.hpp"
#include "XMPUtil.hpp"

using namespace std;

// The Adobe XMP SDK's format handlers use internal global state (including cached
// XMPFiles_IO objects in format-check routines like MP3_CheckFormat) that is not
// safe under concurrent file operations. XMPLifecycleCXX::operationMutex prevents
// two threads from executing any SXMPFiles open/read/write/close sequence
// simultaneously, and also prevents terminate() from zeroing format-handler
// function pointers while an OpenFile() dispatch is in progress.

SXMPMeta XMPUtil::createXMPFromRDF(const string& rdfString) {
    SXMPMeta meta;
    meta.ParseFromBuffer(rdfString.c_str(), (XMP_StringLen)rdfString.size());
    return meta;
}

bool XMPUtil::getXMP(const string& filePath, string* xml, bool* hasPacket, string* errorMessage) {
    XMPLifecycleCXX::initialize();
    std::lock_guard<std::mutex> lock(XMPLifecycleCXX::operationMutex);

    *hasPacket = false;

    try {
        // OnlyXMP is honored by the MPEG-4 handler alone; WAV, AIFF and MP3 import native metadata.
        XMP_OptionBits opts = kXMPFiles_OpenForRead | kXMPFiles_OpenUseSmartHandler | kXMPFiles_OpenOnlyXMP;

        SXMPFiles myFile;

        // First we try and open the file
        bool ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);

        if (!ok) {
            // Now try using packet scanning
            opts = kXMPFiles_OpenForRead | kXMPFiles_OpenUsePacketScanning | kXMPFiles_OpenOnlyXMP;
            ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);
        }

        if (!ok) {
            if (errorMessage != nullptr) *errorMessage = "Failed to open file: " + filePath;
            return false;
        }

        // GetXMP() returns false when there is no packet and nothing native to import. The WAV,
        // AIFF and MP3 handlers import native metadata regardless, so a file of those formats
        // without a packet can still report one.
        SXMPMeta meta;
        if (myFile.GetXMP(&meta)) {
            meta.SerializeToBuffer(xml);
            *hasPacket = true;
        }

        myFile.CloseFile();
    } catch (XMP_Error & e) {
        if (errorMessage != nullptr) *errorMessage = e.GetErrMsg();
        return false;
    }

    return true;
}

bool XMPUtil::writeXMP(const string& xmlString, const string& filePath, string* errorMessage) {
    XMPLifecycleCXX::initialize();
    std::lock_guard<std::mutex> lock(XMPLifecycleCXX::operationMutex);

    SXMPMeta meta;
    if (!XMPUtil::parsePacket(xmlString, &meta, errorMessage)) {
        return false;
    }

    try {
        // No OnlyXMP: the MPEG-4 handler rewrites `moov` from what it parsed at open, and with the
        // flag it parses no native items, so a QuickTime movie loses its `udta` text items.
        XMP_OptionBits opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUseSmartHandler;

        bool ok;
        SXMPFiles myFile;

        // First we try and open the file
        ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);

        if (!ok) {
            // Now try using packet scanning
            opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUsePacketScanning;
            ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);
        }

        // If the file is open then read get the XMP data
        if (!ok) {
            cout << "Failed to open file" << endl;
            if (errorMessage != nullptr) *errorMessage = "Failed to open file: " + filePath;
            return false;
        }

        // Serialize the packet and write the buffer to a file
        // Let the padding be computed and use the default linefeed and indents without limits
        string metaBuffer;
        meta.SerializeToBuffer(&metaBuffer, 0, 0, "", "", 0);

        // Check we can put the XMP packet back into the file
        if (!myFile.CanPutXMP(meta)) {
            cout << "XMPUtil ERROR: Cannot put XMP into " << filePath << endl;
            if (errorMessage != nullptr) *errorMessage = "Cannot put XMP into file: " + filePath;
            myFile.CloseFile();
            return false;
        }

        // Update the file with the modified XMP
        myFile.PutXMP(meta);

        // Close the SXMPFile.  This *must* be called.  The XMP is not
        // actually written and the disk file is not closed until this call is made.
        myFile.CloseFile();
    } catch (XMP_Error & e) {
        cout << "XMPUtil ERROR: " << e.GetErrMsg() << endl;
        if (errorMessage != nullptr) *errorMessage = e.GetErrMsg();
        return false;
    }

    return true;
}

bool XMPUtil::getXMPProperties(
    const string& filePath,
    const std::vector<XMPPropertyRead>& requests,
    std::vector<std::vector<std::string>>* results,
    string* errorMessage
) {
    if (results == nullptr) return false;
    results->clear();
    results->resize(requests.size());

    XMPLifecycleCXX::initialize();
    std::lock_guard<std::mutex> lock(XMPLifecycleCXX::operationMutex);

    try {
        // Read-only open: no update handler needed, and it must not fail on a file we would not
        // be able to write.
        XMP_OptionBits opts = kXMPFiles_OpenForRead | kXMPFiles_OpenUseSmartHandler;

        SXMPFiles myFile;
        bool ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);

        if (!ok) {
            opts = kXMPFiles_OpenForRead | kXMPFiles_OpenUsePacketScanning;
            ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);
        }

        if (!ok) {
            if (errorMessage != nullptr) *errorMessage = "Failed to open file: " + filePath;
            return false;
        }

        SXMPMeta meta;

        // No XMP packet at all is not an error -- every field is simply absent.
        if (!myFile.GetXMP(&meta)) {
            myFile.CloseFile();
            return true;
        }

        XMPUtil::readProperties(meta, requests, results);

        myFile.CloseFile();
    } catch (XMP_Error & e) {
        cout << "XMPUtil ERROR: " << e.GetErrMsg() << endl;
        if (errorMessage != nullptr) *errorMessage = e.GetErrMsg();
        return false;
    }

    return true;
}

bool XMPUtil::setXMPProperty(
    const string& filePath,
    const string& ns,
    const string& propName,
    const string& value,
    string* errorMessage
) {
    XMPLifecycleCXX::initialize();
    std::lock_guard<std::mutex> lock(XMPLifecycleCXX::operationMutex);

    try {
        XMP_OptionBits opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUseSmartHandler;

        SXMPFiles myFile;
        bool ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);

        if (!ok) {
            opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUsePacketScanning;
            ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);
        }

        if (!ok) {
            cout << "XMPUtil ERROR: Failed to open " << filePath << endl;
            if (errorMessage != nullptr) *errorMessage = "Failed to open file: " + filePath;
            return false;
        }

        // Load existing XMP first — GetXMP returns false when the file has no XMP
        // packet yet, which is not an error here; proceed with a default-constructed
        // (empty) meta so the first property write to a fresh file still succeeds.
        SXMPMeta meta;
        myFile.GetXMP(&meta);

        XMPUtil::setScalarProperty(meta, ns, propName, value, false);

        if (!myFile.CanPutXMP(meta)) {
            cout << "XMPUtil ERROR: Cannot put XMP into " << filePath << endl;
            if (errorMessage != nullptr) *errorMessage = "Cannot put XMP into file: " + filePath;
            myFile.CloseFile();
            return false;
        }

        myFile.PutXMP(meta);
        myFile.CloseFile();
    } catch (XMP_Error & e) {
        cout << "XMPUtil ERROR: " << e.GetErrMsg() << endl;
        if (errorMessage != nullptr) *errorMessage = e.GetErrMsg();
        return false;
    }

    return true;
}

bool XMPUtil::setXMPArrayProperty(
    const string& filePath,
    const string& ns,
    const string& propName,
    const vector<string>& values,
    XMP_OptionBits arrayForm,
    string* errorMessage
) {
    XMPLifecycleCXX::initialize();
    std::lock_guard<std::mutex> lock(XMPLifecycleCXX::operationMutex);

    try {
        XMP_OptionBits opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUseSmartHandler;

        SXMPFiles myFile;
        bool ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);

        if (!ok) {
            opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUsePacketScanning;
            ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);
        }

        if (!ok) {
            cout << "XMPUtil ERROR: Failed to open " << filePath << endl;
            if (errorMessage != nullptr) *errorMessage = "Failed to open file: " + filePath;
            return false;
        }

        SXMPMeta meta;
        myFile.GetXMP(&meta);

        // Replace semantics: clear any existing items for this property, then
        // re-add from `values` in order. DeleteProperty is not an error if the
        // property doesn't already exist.
        meta.DeleteProperty(ns.c_str(), propName.c_str());

        for (const auto& value : values) {
            meta.AppendArrayItem(ns.c_str(), propName.c_str(), arrayForm, value.c_str());
        }

        if (!myFile.CanPutXMP(meta)) {
            cout << "XMPUtil ERROR: Cannot put XMP into " << filePath << endl;
            if (errorMessage != nullptr) *errorMessage = "Cannot put XMP into file: " + filePath;
            myFile.CloseFile();
            return false;
        }

        myFile.PutXMP(meta);
        myFile.CloseFile();
    } catch (XMP_Error & e) {
        cout << "XMPUtil ERROR: " << e.GetErrMsg() << endl;
        if (errorMessage != nullptr) *errorMessage = e.GetErrMsg();
        return false;
    }

    return true;
}

bool XMPUtil::setXMPProperties(
    const string& filePath,
    const vector<XMPPropertyWrite>& properties,
    string* errorMessage
) {
    XMPLifecycleCXX::initialize();
    std::lock_guard<std::mutex> lock(XMPLifecycleCXX::operationMutex);

    try {
        XMP_OptionBits opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUseSmartHandler;

        SXMPFiles myFile;
        bool ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);

        if (!ok) {
            opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUsePacketScanning;
            ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);
        }

        if (!ok) {
            cout << "XMPUtil ERROR: Failed to open " << filePath << endl;
            if (errorMessage != nullptr) *errorMessage = "Failed to open file: " + filePath;
            return false;
        }

        SXMPMeta meta;
        myFile.GetXMP(&meta);

        for (const auto& property : properties) {
            if (property.isRemoval) {
                // Deleting a property that is not present is a no-op, not an error -- clearing an
                // already-empty field is the ordinary case.
                meta.DeleteProperty(property.ns.c_str(), property.propName.c_str());
            } else if (property.isArray) {
                meta.DeleteProperty(property.ns.c_str(), property.propName.c_str());
                const XMP_OptionBits arrayForm = property.isOrdered ? kXMP_PropArrayIsOrdered : kXMP_PropArrayIsUnordered;
                for (const auto& value : property.values) {
                    meta.AppendArrayItem(
                        property.ns.c_str(),
                        property.propName.c_str(),
                        arrayForm,
                        value.c_str()
                    );
                }
            } else if (!property.values.empty()) {
                XMPUtil::setScalarProperty(meta, property.ns, property.propName, property.values[0], property.isLocalized);
            }
        }

        if (!myFile.CanPutXMP(meta)) {
            cout << "XMPUtil ERROR: Cannot put XMP into " << filePath << endl;
            if (errorMessage != nullptr) *errorMessage = "Cannot put XMP into file: " + filePath;
            myFile.CloseFile();
            return false;
        }

        myFile.PutXMP(meta);
        myFile.CloseFile();
    } catch (XMP_Error & e) {
        cout << "XMPUtil ERROR: " << e.GetErrMsg() << endl;
        if (errorMessage != nullptr) *errorMessage = e.GetErrMsg();
        return false;
    }

    return true;
}

bool XMPUtil::setXMPTrackInfo(
    const string& filePath,
    const string& trackType,
    const string& trackName,
    string* errorMessage
) {
    XMPLifecycleCXX::initialize();
    std::lock_guard<std::mutex> lock(XMPLifecycleCXX::operationMutex);

    try {
        XMP_OptionBits opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUseSmartHandler;

        SXMPFiles myFile;
        bool ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);

        if (!ok) {
            opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUsePacketScanning;
            ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);
        }

        if (!ok) {
            cout << "XMPUtil ERROR: Failed to open " << filePath << endl;
            if (errorMessage != nullptr) *errorMessage = "Failed to open file: " + filePath;
            return false;
        }

        SXMPMeta meta;
        myFile.GetXMP(&meta);

        static const string ns = "http://ns.adobe.com/xmp/1.0/DynamicMedia/";

        // XMPDynamicMedia reads only the first Tracks entry, so create it as a struct item if absent.
        // A new array needs an explicit array form (kXMP_PropArrayIsUnordered is the plain bag) and a
        // nullptr item value: "" is still a string value, which a struct item refuses.
        if (meta.CountArrayItems(ns.c_str(), "Tracks") == 0) {
            meta.AppendArrayItem(ns.c_str(), "Tracks", kXMP_PropArrayIsUnordered, nullptr, kXMP_PropValueIsStruct);
        }

        if (!trackType.empty()) {
            meta.SetProperty(ns.c_str(), "Tracks[1]/xmpDM:trackType", trackType.c_str());
        }

        if (!trackName.empty()) {
            meta.SetProperty(ns.c_str(), "Tracks[1]/xmpDM:trackName", trackName.c_str());
        }

        if (!myFile.CanPutXMP(meta)) {
            cout << "XMPUtil ERROR: Cannot put XMP into " << filePath << endl;
            if (errorMessage != nullptr) *errorMessage = "Cannot put XMP into file: " + filePath;
            myFile.CloseFile();
            return false;
        }

        myFile.PutXMP(meta);
        myFile.CloseFile();
    } catch (XMP_Error & e) {
        cout << "XMPUtil ERROR: " << e.GetErrMsg() << endl;
        if (errorMessage != nullptr) *errorMessage = e.GetErrMsg();
        return false;
    }

    return true;
}
