// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#include "XMPLifecycleCXX.hpp"
#include "XMPUtil.hpp"

using namespace std;

// The Adobe XMP SDK's format handlers use internal global state (including cached
// XMPFiles_IO objects in format-check routines like MP3_CheckFormat) that is not
// safe under concurrent file operations. This mutex prevents two threads from
// executing any SXMPFiles open/read/write/close sequence simultaneously.
//
// NOTE: This mutex alone is insufficient for combined parse+write operations.
// Another thread's getXMP can run between a caller's getXMP and writeXMP calls,
// leaving stale XMPFiles_IO state that causes the next OpenFile to assert.
// The Swift-level _xmpCopyLock in XMP.swift closes that window by serializing
// the entire parse+write sequence as an atomic unit.
static std::mutex xmpOperationMutex;

SXMPMeta XMPUtil::createXMPFromRDF(const string& rdfString) {
    SXMPMeta meta;
    meta.ParseFromBuffer(rdfString.c_str(), (XMP_StringLen)rdfString.size());
    return meta;
}

string XMPUtil::getXMP(const string& filePath) {
    XMPLifecycleCXX::initialize();
    std::lock_guard<std::mutex> lock(xmpOperationMutex);

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

bool XMPUtil::writeXMP(const string& xmlString, const string& filePath) {
    XMPLifecycleCXX::initialize();
    std::lock_guard<std::mutex> lock(xmpOperationMutex);

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
        return false;
    }

    return true;
}

bool XMPUtil::writeXMPReconciled(const string& xmlString, const string& filePath) {
    XMPLifecycleCXX::initialize();
    std::lock_guard<std::mutex> lock(xmpOperationMutex);

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
            return false;
        }

        SXMPMeta meta = XMPUtil::createXMPFromRDF(xmlString);

        string metaBuffer;
        meta.SerializeToBuffer(&metaBuffer, 0, 0, "", "", 0);

        if (!myFile.CanPutXMP(meta)) {
            cout << "XMPUtil ERROR: Cannot put XMP into " << filePath << endl;
            myFile.CloseFile();
            return false;
        }

        myFile.PutXMP(meta);
        myFile.CloseFile();
    } catch (XMP_Error & e) {
        cout << "XMPUtil ERROR: " << e.GetErrMsg() << endl;
        return false;
    }

    return true;
}

