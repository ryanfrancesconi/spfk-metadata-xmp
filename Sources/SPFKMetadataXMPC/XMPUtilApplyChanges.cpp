// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#include "XMPLifecycleCXX.hpp"
#include "XMPUtil.hpp"

using namespace std;

bool XMPUtil::applyXMPChanges(
    const string* baseline,
    const string& edited,
    const string& filePath,
    string* errorMessage
) {
    XMPLifecycleCXX::initialize();
    std::lock_guard<std::mutex> lock(XMPLifecycleCXX::operationMutex);

    SXMPMeta editedMeta;
    if (!XMPUtil::parsePacket(edited, &editedMeta, errorMessage)) {
        return false;
    }

    try {
        SXMPMeta baselineMeta;
        if (baseline != nullptr) {
            baselineMeta = XMPUtil::createXMPFromRDF(*baseline);
        }

        const vector<PropertyKey> changed = XMPUtil::changedTopLevelProperties(baselineMeta, editedMeta);

        XMP_OptionBits opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUseSmartHandler;

        SXMPFiles myFile;
        bool ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);

        if (!ok) {
            opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUsePacketScanning;
            ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);
        }

        if (!ok) {
            if (errorMessage != nullptr) *errorMessage = "Failed to open file: " + filePath;
            return false;
        }

        SXMPMeta current;
        myFile.GetXMP(&current);

        XMPUtil::applyTopLevelProperties(editedMeta, &current, changed);

        if (!myFile.CanPutXMP(current)) {
            if (errorMessage != nullptr) *errorMessage = "Cannot put XMP into file: " + filePath;
            myFile.CloseFile();
            return false;
        }

        myFile.PutXMP(current);
        myFile.CloseFile();
    } catch (XMP_Error & e) {
        if (errorMessage != nullptr) *errorMessage = e.GetErrMsg();
        return false;
    }

    return true;
}
