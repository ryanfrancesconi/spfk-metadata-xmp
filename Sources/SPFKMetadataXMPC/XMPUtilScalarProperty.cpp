// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#include "XMPLifecycleCXX.hpp"
#include "XMPUtil.hpp"

using namespace std;

void XMPUtil::setScalarProperty(
    SXMPMeta& meta,
    const string& ns,
    const string& propName,
    const string& value,
    bool isLocalized
) {
    string existingValue;
    XMP_OptionBits options = 0;
    const bool exists = meta.GetProperty(ns.c_str(), propName.c_str(), &existingValue, &options);
    const bool existingIsAltText = exists && XMP_PropIsArray(options) && XMP_ArrayIsAltText(options);

    if (!isLocalized && !existingIsAltText) {
        meta.SetProperty(ns.c_str(), propName.c_str(), value.c_str());
        return;
    }

    if (exists && !existingIsAltText) {
        meta.DeleteProperty(ns.c_str(), propName.c_str());
    }

    meta.SetLocalizedText(ns.c_str(), propName.c_str(), "", "x-default", value.c_str());
}
