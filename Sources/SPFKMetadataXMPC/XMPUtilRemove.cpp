// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#include "XMPLifecycleCXX.hpp"
#include "XMPUtil.hpp"

using namespace std;

bool XMPUtil::removeXMP(const string& filePath, string* errorMessage) {
    XMPLifecycleCXX::initialize();
    std::lock_guard<std::mutex> lock(XMPLifecycleCXX::operationMutex);

    try {
        SXMPFiles myFile;
        // OnlyXMP, so the empty put exports nothing into the native metadata.
        const XMP_OptionBits opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUseSmartHandler | kXMPFiles_OpenOnlyXMP;

        if (!myFile.OpenFile(filePath, kXMP_UnknownFile, opts)) {
            if (errorMessage != nullptr) *errorMessage = "Failed to open file: " + filePath;
            return false;
        }

        // Only the MPEG-4 handler keeps XMP apart from native metadata. Closing without a put
        // leaves the file untouched.
        XMP_FileFormat format = kXMP_UnknownFile;
        myFile.GetFileInfo(nullptr, nullptr, &format, nullptr);

        if (format != kXMP_MPEG4File && format != kXMP_MOVFile) {
            myFile.CloseFile();
            if (errorMessage != nullptr) {
                *errorMessage = "XMP can't be removed from this format without removing the native metadata it mirrors";
            }
            return false;
        }

        SXMPMeta empty;
        myFile.PutXMP(empty);
        myFile.CloseFile();
    } catch (XMP_Error & e) {
        if (errorMessage != nullptr) *errorMessage = e.GetErrMsg();
        return false;
    }

    return true;
}
