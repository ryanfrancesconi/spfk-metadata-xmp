// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#include <set>
#include <utility>

#include "XMPLifecycleCXX.hpp"
#include "XMPUtil.hpp"

using namespace std;

namespace {
    using PropertyKey = pair<string, string>; // schema namespace, top-level property path

    void collectTopLevelProperties(const SXMPMeta& meta, set<PropertyKey>* keys) {
        string schemaNS;
        SXMPIterator schemas(meta, kXMP_IterJustChildren);

        while (schemas.Next(&schemaNS)) {
            string propertyNS;
            string propPath;
            SXMPIterator properties(meta, schemaNS.c_str(), kXMP_IterJustChildren);

            while (properties.Next(&propertyNS, &propPath)) {
                if (!propPath.empty()) keys->insert({ schemaNS, propPath });
            }
        }
    }

    /// The property's subtree serialized on its own, or "" when `meta` lacks it.
    string serializedSubtree(const SXMPMeta& meta, const PropertyKey& key) {
        if (!meta.DoesPropertyExist(key.first.c_str(), key.second.c_str())) return "";

        SXMPMeta subtree;
        SXMPUtils::DuplicateSubtree(meta, &subtree, key.first.c_str(), key.second.c_str());

        string buffer;
        subtree.SerializeToBuffer(&buffer, kXMP_OmitPacketWrapper);
        return buffer;
    }
}

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

        set<PropertyKey> keys;
        collectTopLevelProperties(baselineMeta, &keys);
        collectTopLevelProperties(editedMeta, &keys);

        vector<PropertyKey> changed;
        for (const auto& key : keys) {
            if (serializedSubtree(baselineMeta, key) != serializedSubtree(editedMeta, key)) {
                changed.push_back(key);
            }
        }

        XMP_OptionBits opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUseSmartHandler | kXMPFiles_OpenOnlyXMP;

        SXMPFiles myFile;
        bool ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);

        if (!ok) {
            opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUsePacketScanning | kXMPFiles_OpenOnlyXMP;
            ok = myFile.OpenFile(filePath, kXMP_UnknownFile, opts);
        }

        if (!ok) {
            if (errorMessage != nullptr) *errorMessage = "Failed to open file: " + filePath;
            return false;
        }

        SXMPMeta current;
        myFile.GetXMP(&current);

        for (const auto& key : changed) {
            current.DeleteProperty(key.first.c_str(), key.second.c_str());

            if (editedMeta.DoesPropertyExist(key.first.c_str(), key.second.c_str())) {
                SXMPUtils::DuplicateSubtree(editedMeta, &current, key.first.c_str(), key.second.c_str());
            }
        }

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
