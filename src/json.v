import json
import os
import time
type CategoryId = string | int
struct Asset {
	asset_name string @[json: assetName]
	asset_status struct {
		alert ?string
		abnormal []int
		normal bool
	} @[json: assetStatus]
	asset_uuid string @[json: assetUuid]
	category string
	category_color string @[json: categoryColor]
	category_id CategoryId @[json: categoryId]
	category_logo_url string @[json: categoryLogoUrl]
	external_asset_id string @[json: externalAssetId]
	floor string
	location struct {
		city string
		country string
		lat string
		lon string
		postcode string
		state string
		street_name string @[json: streetName]
		street_number string @[json: streetNumber]
	}
	logo_color string @[json: logoColor]
	logo_url string @[json: logoUrl]
	op_mode int  @[json: opMode]
	unit_name string @[json: unitName]
	view_style int @[json: viewStyle]
}

fn main(){
	text := os.read_file('./src/data.json') or {
		println('Error reading file: $err')
		return
	}
	start := time.now()
	json_data := json.decode([]Asset, text) or {
		println('Error decoding JSON: $err')
		return
	}
	end := time.now()
	println('Time taken to decode JSON: ${end - start}')
	println('json_data: ${json_data[1000]}')
	os.write_file('./src/result.json', json.encode(json_data)) or {
		println('Error writing file: $err')
		return
	}
}
