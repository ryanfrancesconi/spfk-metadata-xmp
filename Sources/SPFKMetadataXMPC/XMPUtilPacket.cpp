// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#include <set>

#include "XMPLifecycleCXX.hpp"
#include "XMPUtil.hpp"

using namespace std;

namespace {
    void collectTopLevelProperties(const SXMPMeta& meta, set<XMPUtil::PropertyKey>* keys) {
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
    string serializedSubtree(const SXMPMeta& meta, const XMPUtil::PropertyKey& key) {
        if (!meta.DoesPropertyExist(key.first.c_str(), key.second.c_str())) return "";

        SXMPMeta subtree;
        SXMPUtils::DuplicateSubtree(meta, &subtree, key.first.c_str(), key.second.c_str());

        string buffer;
        subtree.SerializeToBuffer(&buffer, kXMP_OmitPacketWrapper);
        return buffer;
    }

    bool hasProperties(const SXMPMeta& meta) {
        string schemaNS;
        SXMPIterator schemas(meta, kXMP_IterJustChildren);
        return schemas.Next(&schemaNS);
    }
}

vector<XMPUtil::PropertyKey> XMPUtil::changedTopLevelProperties(const SXMPMeta& baseline, const SXMPMeta& edited) {
    set<PropertyKey> keys;
    collectTopLevelProperties(baseline, &keys);
    collectTopLevelProperties(edited, &keys);

    vector<PropertyKey> changed;
    for (const auto& key : keys) {
        if (serializedSubtree(baseline, key) != serializedSubtree(edited, key)) {
            changed.push_back(key);
        }
    }
    return changed;
}

void XMPUtil::applyTopLevelProperties(const SXMPMeta& edited, SXMPMeta* current, const vector<PropertyKey>& keys) {
    for (const auto& key : keys) {
        current->DeleteProperty(key.first.c_str(), key.second.c_str());

        if (edited.DoesPropertyExist(key.first.c_str(), key.second.c_str())) {
            SXMPUtils::DuplicateSubtree(edited, current, key.first.c_str(), key.second.c_str());
        }
    }
}

void XMPUtil::readProperties(
    const SXMPMeta& meta,
    const vector<XMPPropertyRead>& requests,
    vector<vector<string>>* results
) {
    results->clear();
    results->resize(requests.size());

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
}

bool XMPUtil::getPacketProperties(
    const string& packet,
    const vector<XMPPropertyRead>& requests,
    vector<vector<string>>* results,
    string* errorMessage
) {
    if (results == nullptr) return false;

    XMPLifecycleCXX::initialize();
    std::lock_guard<std::mutex> lock(XMPLifecycleCXX::operationMutex);

    try {
        SXMPMeta meta = XMPUtil::createXMPFromRDF(packet);
        XMPUtil::readProperties(meta, requests, results);
    } catch (XMP_Error & e) {
        if (errorMessage != nullptr) *errorMessage = e.GetErrMsg();
        return false;
    }

    return true;
}

bool XMPUtil::changedXMPProperties(
    const string* baseline,
    const string& edited,
    vector<PropertyKey>* changed,
    string* errorMessage
) {
    if (changed == nullptr) return false;

    XMPLifecycleCXX::initialize();
    std::lock_guard<std::mutex> lock(XMPLifecycleCXX::operationMutex);

    try {
        SXMPMeta baselineMeta;
        if (baseline != nullptr) baselineMeta = XMPUtil::createXMPFromRDF(*baseline);

        SXMPMeta editedMeta = XMPUtil::createXMPFromRDF(edited);
        *changed = XMPUtil::changedTopLevelProperties(baselineMeta, editedMeta);
    } catch (XMP_Error & e) {
        if (errorMessage != nullptr) *errorMessage = e.GetErrMsg();
        return false;
    }

    return true;
}

bool XMPUtil::mergeXMPChanges(
    const string* baseline,
    const string& edited,
    const string* current,
    string* merged,
    string* errorMessage
) {
    if (merged == nullptr) return false;

    XMPLifecycleCXX::initialize();
    std::lock_guard<std::mutex> lock(XMPLifecycleCXX::operationMutex);

    SXMPMeta editedMeta;
    if (!XMPUtil::parsePacket(edited, &editedMeta, errorMessage)) {
        return false;
    }

    try {
        SXMPMeta baselineMeta;
        if (baseline != nullptr) baselineMeta = XMPUtil::createXMPFromRDF(*baseline);

        SXMPMeta currentMeta;
        if (current != nullptr) currentMeta = XMPUtil::createXMPFromRDF(*current);

        XMPUtil::applyTopLevelProperties(
            editedMeta, &currentMeta, XMPUtil::changedTopLevelProperties(baselineMeta, editedMeta)
        );

        merged->clear();
        if (hasProperties(currentMeta)) {
            currentMeta.SerializeToBuffer(merged);
        }
    } catch (XMP_Error & e) {
        if (errorMessage != nullptr) *errorMessage = e.GetErrMsg();
        return false;
    }

    return true;
}
