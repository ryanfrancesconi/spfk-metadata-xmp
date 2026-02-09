// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#include "XMPLifecycleCXX.hpp"
#include "XMPUtil.hpp"

using namespace std;

SXMPMeta XMPUtil::createXMPFromRDF(string string) {
    const char *cstring = string.c_str();

    SXMPMeta meta;

    // Loop over the string and create the XMP object
    // 10 characters at a time
    int i;

    for (i = 0; i < (long)strlen(cstring) - 10; i += 10) {
        meta.ParseFromBuffer(&string[i], 10, kXMP_ParseMoreBuffers);
    }

    // The last call has no kXMP_ParseMoreBuffers options, signifying
    // this is the last input buffer
    meta.ParseFromBuffer(&cstring[i], (XMP_StringLen)strlen(cstring) - i);

    return meta;
}

string XMPUtil::getXMP(string filePath) {
    XMPLifecycleCXX::initialize();

    string buffer;

    try {
        // Options to open the file with - read only and use a file handler
        XMP_OptionBits opts = kXMPFiles_OpenForRead | kXMPFiles_OpenUseSmartHandler;

        SXMPFiles myFile;
        string status = "";

        // First we try and open the file
        bool ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);

        if (!ok) {
            status += "No smart handler available for " + filePath + "\n";
            status += "Trying packet scanning.\n";

            // Now try using packet scanning
            opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUsePacketScanning;
            ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);
        }

        // If the file is open then read the metadata
        if (!ok) {
            cout << "XMPUtil Error: Failed to open " << filePath << endl;
            return "";
        }

        cout << status << endl;

        // cout << filename << " is opened successfully" << endl;

        // Create the xmp object and get the xmp data
        SXMPMeta meta;
        myFile.GetXMP(&meta);
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

bool XMPUtil::writeXMP(string xmlString, string filePath) {
    XMPLifecycleCXX::initialize();

    try {
        // Options to open the file with - open for editing and use a smart handler
        XMP_OptionBits opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUseSmartHandler;

        bool ok;
        SXMPFiles myFile;

        // First we try and open the file
        ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);

        string status = "";

        if (!ok) {
            status += "No smart handler available for " + filePath + "\n";
            status += "Trying packet scanning.\n";

            // Now try using packet scanning
            opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUsePacketScanning;
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
        if (myFile.CanPutXMP(meta)) {
            // If so then update the file with the modified XMP
            myFile.PutXMP(meta);
        }

        // Close the SXMPFile.  This *must* be called.  The XMP is not
        // actually written and the disk file is not closed until this call is made.
        myFile.CloseFile();

        //
    } catch (XMP_Error & e) {
        cout << "XMPUtil ERROR: " << e.GetErrMsg() << endl;
        return false;
    }

    return true;
}
