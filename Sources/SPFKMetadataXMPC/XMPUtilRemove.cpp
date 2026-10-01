// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#include <set>
#include <utility>

#include "XMPLifecycleCXX.hpp"
#include "XMPUtil.hpp"

using namespace std;

namespace {
    /// Whether the MPEG-4 handler imports this property from native metadata (`mvhd`, `cprt`,
    /// timecode, `udta` reel name, Premiere's `PrmL`/`Cr8r`) and exports it back on a put.
    bool isNativeMirrored(const string& schemaNS, const string& propPath) {
        if (schemaNS == kXMP_NS_CreatorAtom) return true;

        static const set<pair<string, string>> mirrored = {
            { kXMP_NS_XMP, "xmp:CreateDate" },
            { kXMP_NS_XMP, "xmp:ModifyDate" },
            { kXMP_NS_XMP, "xmp:CreatorTool" },
            { kXMP_NS_DM, "xmpDM:duration" },
            { kXMP_NS_DM, "xmpDM:tapeName" },
            { kXMP_NS_DM, "xmpDM:altTapeName" },
            { kXMP_NS_DM, "xmpDM:startTimecode" },
            { kXMP_NS_DM, "xmpDM:startTimeScale" },
            { kXMP_NS_DM, "xmpDM:startTimeSampleSize" },
            { kXMP_NS_DM, "xmpDM:altTimecode" },
            { kXMP_NS_DM, "xmpDM:projectRef" },
            { kXMP_NS_DC, "dc:rights" },
        };

        return mirrored.contains({ schemaNS, propPath });
    }
}

bool XMPUtil::removeXMP(const string& filePath, string* errorMessage) {
    XMPLifecycleCXX::initialize();
    std::lock_guard<std::mutex> lock(XMPLifecycleCXX::operationMutex);

    try {
        SXMPFiles myFile;
        // No OnlyXMP: the put exports what is kept, so the handler needs the native state.
        const XMP_OptionBits opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUseSmartHandler;

        if (!myFile.OpenFile(filePath, kXMP_UnknownFile, opts)) {
            if (errorMessage != nullptr) *errorMessage = "Failed to open file: " + filePath;
            return false;
        }

        // Closing without a put leaves the file untouched.
        XMP_FileFormat format = kXMP_UnknownFile;
        myFile.GetFileInfo(nullptr, nullptr, &format, nullptr);

        if (format != kXMP_MPEG4File && format != kXMP_MOVFile) {
            myFile.CloseFile();
            if (errorMessage != nullptr) {
                *errorMessage = "XMP can't be removed from this format without removing the native metadata it mirrors";
            }
            return false;
        }

        SXMPMeta meta;
        if (!myFile.GetXMP(&meta)) {
            myFile.CloseFile();
            return true;
        }

        vector<pair<string, string>> removals;
        string schemaNS;
        SXMPIterator schemas(meta, kXMP_IterJustChildren);

        while (schemas.Next(&schemaNS)) {
            string propertyNS;
            string propPath;
            SXMPIterator properties(meta, schemaNS.c_str(), kXMP_IterJustChildren);

            while (properties.Next(&propertyNS, &propPath)) {
                if (!propPath.empty() && !isNativeMirrored(schemaNS, propPath)) {
                    removals.push_back({ schemaNS, propPath });
                }
            }
        }

        for (const auto& [ns, path] : removals) {
            meta.DeleteProperty(ns.c_str(), path.c_str());
        }

        if (!myFile.CanPutXMP(meta)) {
            if (errorMessage != nullptr) *errorMessage = "Cannot put XMP into file: " + filePath;
            myFile.CloseFile();
            return false;
        }

        myFile.PutXMP(meta);
        myFile.CloseFile();
    } catch (XMP_Error & e) {
        if (errorMessage != nullptr) *errorMessage = e.GetErrMsg();
        return false;
    }

    return true;
}
