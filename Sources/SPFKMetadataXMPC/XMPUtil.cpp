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
//
// NOTE: This mutex alone is insufficient for combined parse+write operations.
// Another thread's getXMP can run between a caller's getXMP and writeXMP calls,
// leaving stale XMPFiles_IO state that causes the next OpenFile to assert.
// The Swift-level _xmpCopyLock in XMP.swift closes that window by serializing
// the entire parse+write sequence as an atomic unit.

SXMPMeta XMPUtil::createXMPFromRDF(const string& rdfString) {
    SXMPMeta meta;
    meta.ParseFromBuffer(rdfString.c_str(), (XMP_StringLen)rdfString.size());
    return meta;
}

string XMPUtil::getXMP(const string& filePath) {
    XMPLifecycleCXX::initialize();
    std::lock_guard<std::mutex> lock(XMPLifecycleCXX::operationMutex);

    string buffer;

    try {
        // Read only XMP — skip reconciliation with legacy metadata (BEXT, iXML, etc.)
        XMP_OptionBits opts = kXMPFiles_OpenForRead | kXMPFiles_OpenUseSmartHandler | kXMPFiles_OpenOnlyXMP;

        SXMPFiles myFile;
        string status = "";

        // First we try and open the file
        bool ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);

        if (!ok) {
            status += "No smart handler available for " + filePath + "\n";
            status += "Trying packet scanning.\n";

            // Now try using packet scanning
            opts = kXMPFiles_OpenForRead | kXMPFiles_OpenUsePacketScanning | kXMPFiles_OpenOnlyXMP;
            ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);
        }

        // If the file is open then read the metadata
        if (!ok) {
            cout << "XMPUtil Error: Failed to open " << filePath << endl;
            return "";
        }

        // cout << status << endl;

        // cout << filename << " is opened successfully" << endl;

        // Create the xmp object and get the xmp data.
        // GetXMP() returns false when the file has no XMP packet; in that case
        // meta stays default-constructed and SerializeToBuffer would produce a
        // minimal XML envelope — not actual metadata.  Return "" so the caller
        // can distinguish "no XMP" from "has XMP".
        SXMPMeta meta;
        if (!myFile.GetXMP(&meta)) {
            myFile.CloseFile();
            return "";
        }
        meta.SerializeToBuffer(&buffer);

        // this will print the raw xml:
        // cout << buffer;

        myFile.CloseFile();
    } catch (XMP_Error & e) {
        cout << "XMPUtil ERROR: " << e.GetErrMsg() << endl;
        return "";
    }

    return buffer;
}

bool XMPUtil::writeXMP(const string& xmlString, const string& filePath, string* errorMessage) {
    XMPLifecycleCXX::initialize();
    std::lock_guard<std::mutex> lock(XMPLifecycleCXX::operationMutex);

    try {
        // Write only XMP — skip reconciliation with legacy metadata (BEXT, iXML, etc.)
        XMP_OptionBits opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUseSmartHandler | kXMPFiles_OpenOnlyXMP;

        bool ok;
        SXMPFiles myFile;

        // First we try and open the file
        ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);

        string status = "";

        if (!ok) {
            status += "No smart handler available for " + filePath + "\n";
            status += "Trying packet scanning.\n";

            // Now try using packet scanning
            opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUsePacketScanning | kXMPFiles_OpenOnlyXMP;
            ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);
        }

        // If the file is open then read get the XMP data
        if (!ok) {
            cout << "Failed to open file" << endl;
            if (errorMessage != nullptr) *errorMessage = "Failed to open file: " + filePath;
            return false;
        }

        cout << status << endl;
        cout << filePath << " is opened successfully" << endl;

        SXMPMeta meta = XMPUtil::createXMPFromRDF(xmlString);

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

        for (size_t i = 0; i < requests.size(); ++i) {
            const auto& request = requests[i];
            auto& out = (*results)[i];

            // Per-property isolation: one field in an odd shape must not fail the whole read.
            // The toolkit throws rather than returning false for several mismatches -- asking
            // GetLocalizedText for a plain scalar raises "Localized text array is not alt-text".
            try {
                if (request.isArray) {
                    const XMP_Index count = meta.CountArrayItems(request.ns.c_str(), request.propName.c_str());
                    for (XMP_Index item = 1; item <= count; ++item) {
                        string value;
                        if (meta.GetArrayItem(request.ns.c_str(), request.propName.c_str(), item, &value, nullptr)) {
                            out.push_back(value);
                        }
                    }
                    continue;
                }

                string value;
                XMP_OptionBits options = 0;

                // Ask what shape the property actually is rather than guessing. A caller cannot
                // know which scalars the toolkit has reconciled into a language alternative, and
                // choosing the wrong accessor either throws or silently returns nothing.
                if (!meta.GetProperty(request.ns.c_str(), request.propName.c_str(), &value, &options)) {
                    continue;
                }

                if (XMP_PropIsArray(options) && XMP_ArrayIsAltText(options)) {
                    string localized;
                    string actualLang;
                    if (meta.GetLocalizedText(
                            request.ns.c_str(), request.propName.c_str(), "", "x-default",
                            &actualLang, &localized, nullptr
                        )) {
                        out.push_back(localized);
                    }
                } else if (!XMP_PropIsArray(options)) {
                    out.push_back(value);
                }
            } catch (XMP_Error & e) {
                cout << "XMPUtil: skipping " << request.ns << ":" << request.propName
                     << " — " << e.GetErrMsg() << endl;
            }
        }

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
        XMP_OptionBits opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUseSmartHandler | kXMPFiles_OpenOnlyXMP;

        SXMPFiles myFile;
        bool ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);

        if (!ok) {
            opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUsePacketScanning | kXMPFiles_OpenOnlyXMP;
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

        meta.SetProperty(ns.c_str(), propName.c_str(), value.c_str());

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
        XMP_OptionBits opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUseSmartHandler | kXMPFiles_OpenOnlyXMP;

        SXMPFiles myFile;
        bool ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);

        if (!ok) {
            opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUsePacketScanning | kXMPFiles_OpenOnlyXMP;
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
        XMP_OptionBits opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUseSmartHandler | kXMPFiles_OpenOnlyXMP;

        SXMPFiles myFile;
        bool ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);

        if (!ok) {
            opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUsePacketScanning | kXMPFiles_OpenOnlyXMP;
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
                for (const auto& value : property.values) {
                    meta.AppendArrayItem(
                        property.ns.c_str(),
                        property.propName.c_str(),
                        kXMP_PropArrayIsUnordered,
                        value.c_str()
                    );
                }
            } else if (!property.values.empty()) {
                meta.SetProperty(property.ns.c_str(), property.propName.c_str(), property.values[0].c_str());
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
        XMP_OptionBits opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUseSmartHandler | kXMPFiles_OpenOnlyXMP;

        SXMPFiles myFile;
        bool ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);

        if (!ok) {
            opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUsePacketScanning | kXMPFiles_OpenOnlyXMP;
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

        // Mirrors XMPMetadata's read path, which only ever looks at the first track
        // entry — create the Tracks bag's first (struct-typed) item if none exists yet.
        //
        // `arrayOptions` must be an explicit array-type flag when creating a brand-new
        // array — kXMP_NoOptions ("match existing type") only works when the array
        // already exists; the real toolkit rejects it for a new array with "Explicit
        // arrayOptions required to create new array" (confirmed at runtime). Since
        // kXMP_PropArrayIsOrdered is documented as "Implies kXMP_PropValueIsArray"
        // (XMP_Const.h), kXMP_PropArrayIsUnordered — #defined as kXMP_PropValueIsArray,
        // the same base bit without the ordered bit layered on — is the correct explicit
        // "plain bag" request, not an invalid value; that part of the original code was
        // right. `itemValue` does need to be nullptr, not "" — a non-null empty string
        // is still "a string value" to the toolkit, which is what the *previous* runtime
        // error ("Structs and arrays can't have string values") was actually about,
        // confirmed fixed once this was changed.
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

bool XMPUtil::writeXMPReconciled(const string& xmlString, const string& filePath, string* errorMessage) {
    XMPLifecycleCXX::initialize();
    std::lock_guard<std::mutex> lock(XMPLifecycleCXX::operationMutex);

    try {
        // Write XMP WITH reconciliation — allows Adobe SDK to update native BEXT/iXML chunks
        XMP_OptionBits opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUseSmartHandler;

        bool ok;
        SXMPFiles myFile;

        ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);

        if (!ok) {
            opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUsePacketScanning;
            ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);
        }

        if (!ok) {
            cout << "Failed to open file" << endl;
            if (errorMessage != nullptr) *errorMessage = "Failed to open file: " + filePath;
            return false;
        }

        SXMPMeta meta = XMPUtil::createXMPFromRDF(xmlString);

        string metaBuffer;
        meta.SerializeToBuffer(&metaBuffer, 0, 0, "", "", 0);

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

