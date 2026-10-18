extends Node
## Product lookup is separate from barcode identity. Unknown means unknown—never random faction.

const SOURCE := "open_food_facts"


func resolve(barcode: String) -> Dictionary:
	var code := BarcodeIdentity.canonicalize(barcode)
	if not BarcodeIdentity.is_supported_retail(code):
		return {"ok": false, "reason": "unsupported_barcode", "message": "Unsupported retail barcode."}
	var fields := "categories_tags,categories,generic_name,labels_tags,product_name,product_name_en,alcohol_100g,nutriments,ingredients_analysis_tags"
	var url := "https://world.openfoodfacts.org/api/v2/product/%s.json?fields=%s" % [code.uri_encode(), fields.uri_encode()]
	var http := HTTPRequest.new()
	add_child(http)
	var err := http.request(url, PackedStringArray(["Accept: application/json"]))
	if err != OK:
		http.queue_free()
		return {"ok": false, "reason": "network_start", "message": "Product lookup could not start."}
	var response: Array = await http.request_completed
	http.queue_free()
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS or int(response[1]) != 200:
		return {"ok": false, "reason": "network", "message": "Could not verify this barcode online."}
	var parsed = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("status", 0)) != 1:
		return {"ok": false, "reason": "unknown_product", "message": "Unknown barcode — product type could not be verified."}
	var product: Variant = parsed.get("product", {})
	if typeof(product) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "invalid_product", "message": "Product lookup returned invalid data."}
	var info := WarriorFactory.classify_product_dict(product)
	var category := int(info.get("category", -1))
	if category < 0:
		return {"ok": false, "reason": "unknown_category", "message": "Product found, but its beverage type is unknown."}
	return {
		"ok": true,
		"source": SOURCE,
		"category": category,
		"category_label": FactionData.category_label(category),
		"faction": FactionData.faction_for_category(category),
	}
