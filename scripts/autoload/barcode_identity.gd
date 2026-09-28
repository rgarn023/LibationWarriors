extends Node
## Canonical barcode identity for Libation Warriors.
## Retail identity is: normalized barcode -> SHA-256 -> deterministic seed.
## The hash is the global identity; the raw barcode stays user-owned/local.

const RETAIL_LENGTHS := [8, 12, 13]
const INTERNAL_PREFIXES := ["DUN-", "LOCAL-", "DEMO-", "EVENT-", "LW-"]


func canonicalize(raw_code: String, symbology: String = "") -> String:
	var raw := raw_code.strip_edges().to_upper()
	if raw.is_empty():
		return ""
	for prefix in INTERNAL_PREFIXES:
		if raw.begins_with(prefix):
			return raw.replace(" ", "")

	var digits := ""
	for i in raw.length():
		var cp := raw.unicode_at(i)
		if cp >= 48 and cp <= 57:
			digits += char(cp)
		elif cp in [32, 45, 46]:
			continue
		else:
			return ""

	if symbology.to_upper() in ["UPC_E", "UPC-E", "UPCE"] and digits.length() == 8:
		var expanded := _expand_upc_e(digits)
		if not expanded.is_empty():
			digits = expanded

	# EAN-13 with a leading zero is the same GTIN identity as UPC-A.
	if digits.length() == 13 and digits.begins_with("0"):
		digits = digits.substr(1)

	if digits.length() not in RETAIL_LENGTHS:
		return ""
	return digits


func is_supported_retail(raw_code: String, symbology: String = "") -> bool:
	var code := canonicalize(raw_code, symbology)
	if code.is_empty():
		return false
	for prefix in INTERNAL_PREFIXES:
		if code.begins_with(prefix):
			return false
	return code.length() in RETAIL_LENGTHS


func sha256_hex(raw_code: String, symbology: String = "") -> String:
	var code := canonicalize(raw_code, symbology)
	if code.is_empty():
		return ""
	var ctx := HashingContext.new()
	if ctx.start(HashingContext.HASH_SHA256) != OK:
		return ""
	ctx.update(code.to_utf8_buffer())
	return ctx.finish().hex_encode()


func seed_from_barcode(raw_code: String, symbology: String = "") -> int:
	var digest := sha256_hex(raw_code, symbology)
	if digest.length() < 15:
		return 1
	# 15 hex digits = 60 bits, safely inside signed int64.
	var seed := int(digest.substr(0, 15).hex_to_int())
	return maxi(1, seed)


func short_id(raw_code: String) -> String:
	var digest := sha256_hex(raw_code)
	return digest.substr(0, mini(10, digest.length())).to_upper()


func _expand_upc_e(code: String) -> String:
	# UPC-E is NS + six compressed payload digits + check digit.
	if code.length() != 8:
		return ""
	var ns := code.substr(0, 1)
	if ns not in ["0", "1"]:
		return ""
	var d := code.substr(1, 6)
	var check := code.substr(7, 1)
	var last := d.substr(5, 1)
	var body := ""
	match last:
		"0", "1", "2":
			body = ns + d.substr(0, 2) + last + "0000" + d.substr(2, 3)
		"3":
			body = ns + d.substr(0, 3) + "00000" + d.substr(3, 2)
		"4":
			body = ns + d.substr(0, 4) + "00000" + d.substr(4, 1)
		_:
			body = ns + d.substr(0, 5) + "0000" + last
	return body + check
