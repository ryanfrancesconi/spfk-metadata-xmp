// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#include "XMPLifecycleCXX.hpp"
#include "XMPUtil.hpp"

using namespace std;

void XMPUtil::applyPropertyWrite(SXMPMeta& meta, const XMPPropertyWrite& property) {
    const char* ns = property.ns.c_str();
    const char* name = property.propName.c_str();

    if (!property.structName.empty()) {
        const char* structName = property.structName.c_str();

        // Deleting a struct's last field deletes the struct with it.
        if (property.isRemoval) {
            meta.DeleteStructField(ns, structName, ns, name);
        } else if (!property.values.empty()) {
            meta.SetStructField(ns, structName, ns, name, property.values[0].c_str());
        }
        return;
    }

    if (property.isRemoval) {
        // Deleting a property that is not present is a no-op, not an error -- clearing an
        // already-empty field is the ordinary case.
        meta.DeleteProperty(ns, name);
    } else if (property.isArray) {
        meta.DeleteProperty(ns, name);
        const XMP_OptionBits arrayForm = property.isOrdered ? kXMP_PropArrayIsOrdered : kXMP_PropArrayIsUnordered;
        // Created even with no items, so an empty array is present rather than absent.
        meta.SetProperty(ns, name, nullptr, arrayForm);
        for (const auto& value : property.values) {
            meta.AppendArrayItem(ns, name, arrayForm, value.c_str());
        }
    } else if (!property.values.empty()) {
        XMPUtil::setScalarProperty(meta, property.ns, property.propName, property.values[0], property.isLocalized);
    }
}
