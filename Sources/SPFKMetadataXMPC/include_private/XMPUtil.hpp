#include <cstdio>
#include <cstring>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

#ifndef XMP_UTILS_H
#define XMP_UTILS_H

#define MAC_ENV              1

// Must be defined to instantiate template classes
#define TXMP_STRING_TYPE     std::string

// Must be defined to give access to XMPFiles
#define XMP_INCLUDE_XMPFILES 1

// Ensure XMP templates are instantiated
#include "XMP.incl_cpp"

// Provide access to the API
#include "XMP.hpp"

using namespace std;

//namespace XMPUtil {
class XMPUtil {
private:
    inline static bool _isInitialized = false;

public:
    // MARK: - Init

    static bool isInitialized() {
        return _isInitialized;
    }

    static bool initialize() {
        if (_isInitialized) {
            return true;
        }

        if (!SXMPMeta::Initialize()) {
            cout << "Could not initialize toolkit!";

            return false;
        }

        XMP_OptionBits options = 0;

#if UNIX_ENV
        options |= kXMPFiles_ServerMode;
#endif

        // Must initialize SXMPFiles before we use it
        if (!SXMPFiles::Initialize(options) ) {
            cout << "Could not initialize SXMPFiles.";
            return false;
        }

        _isInitialized = true;
        return true;
    }

    static void terminate() {
        if (!_isInitialized) {
            return;
        }

        SXMPFiles::Terminate();
        SXMPMeta::Terminate();
    }

    // MARK: - Helpers

    /**
     * Creates an XMP object from an RDF string.  The string is used to
     * to simulate creating and XMP object from multiple input buffers.
     * The last call to ParseFromBuffer has no kXMP_ParseMoreBuffers options,
     * thereby indicating this is the last input buffer.
     */
    static SXMPMeta
    createXMPFromRDF(std::string string) {
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

    /**
     * Initializes the toolkit and attempts to open a file for reading metadata.  Initially
     * an attempt to open the file is done with a handler, if this fails then the file is opened with
     * packet scanning. The XMP object is then returned as a string
     */
    static string getXMP(string filename) {
        if (!_isInitialized) {
            XMPUtil::initialize();
        }

        std::string buffer;

        try {
            // Options to open the file with - read only and use a file handler
            XMP_OptionBits opts = kXMPFiles_OpenForRead | kXMPFiles_OpenUseSmartHandler;

            SXMPFiles myFile;
            std::string status = "";

            // First we try and open the file
            bool ok = myFile.OpenFile(filename, kXMP_UnknownFile, opts);

            if (!ok) {
                status += "No smart handler available for " + filename + "\n";
                status += "Trying packet scanning.\n";

                // Now try using packet scanning
                opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUsePacketScanning;
                ok = myFile.OpenFile(filename, kXMP_UnknownFile, opts);
            }

            // If the file is open then read the metadata
            if (!ok) {
                cout << "Error: Unable to open " << filename << endl;
                //
            } else {
                cout << status << endl;

                // cout << filename << " is opened successfully" << endl;

                // Create the xmp object and get the xmp data
                SXMPMeta meta;
                myFile.GetXMP(&meta);
                meta.SerializeToBuffer(&buffer);

                // this will print the raw xml:
                // cout << buffer;

                myFile.CloseFile();
            }
        } catch(XMP_Error & e) {
            cout << "ERROR: " << e.GetErrMsg() << endl;
            return NULL;
        }

        return buffer;
    }

    static void writeXMP(std::string xmpMetaString, std::string filePath) {
        if (!_isInitialized) {
            initialize();
        }

        try {
            // Options to open the file with - open for editing and use a smart handler
            XMP_OptionBits opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUseSmartHandler;

            bool ok;
            SXMPFiles myFile;
            std::string status = "";

            // First we try and open the file
            ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);

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
                return;
            }

            cout << status << endl;
            cout << filePath << " is opened successfully" << endl;

            SXMPMeta meta = XMPUtil::createXMPFromRDF(xmpMetaString);

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
        } catch(XMP_Error & e) {
            cout << "ERROR: " << e.GetErrMsg() << endl;
            return NULL;
        }
    }
};

#endif // !XMP_UTILS_H
