// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#include "XMPLifecycleCXX.hpp"
#include "XMPUtil.hpp"

using namespace std;

bool XMPUtil::parsePacket(const string& xmlString, SXMPMeta* meta, string* errorMessage) {
    try {
        *meta = XMPUtil::createXMPFromRDF(xmlString);
    } catch (XMP_Error & e) {
        if (errorMessage != nullptr) *errorMessage = e.GetErrMsg();
        return false;
    }

    // Parsing deletes empty schemas, so a tree with no schema has no properties.
    string schemaNS;
    SXMPIterator schemas(*meta, kXMP_IterJustChildren);

    if (!schemas.Next(&schemaNS)) {
        if (errorMessage != nullptr) *errorMessage = "Packet contains no XMP properties";
        return false;
    }

    return true;
}
