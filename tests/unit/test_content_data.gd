extends GutTest
## Real data. Content tasks append pinned-value tests.


func test_real_content_loads_without_errors() -> void:
	var db := ContentDB.load_dir()
	assert_eq(db.errors, [] as Array[String])
	assert_eq(db.validate(), [] as Array[String])
