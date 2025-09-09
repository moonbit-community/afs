///|
/// AFS 基本测试套件

///|
/// 测试工具函数：创建临时文件路径
fn temp_path(name : String) -> Path {
  to_utf8_bytes("/tmp/afs_test_" + name)
}

///|
/// 测试：基本文件读写
test "afs basic file read write" {
  @async.with_event_loop(fn(_) {
    let test_path = temp_path("basic_rw.txt")
    let test_data = b"Hello, AFS World!\nThis is a test file."

    // 写入文件
    write_all(test_path, test_data[:])

    // 验证文件存在
    assert_true(exists(test_path))

    // 读取文件内容
    let read_data = read_all(test_path, None)
    assert_eq(read_data, test_data)

    // 验证文件元数据
    let metadata = stat(test_path)
    assert_eq(metadata.kind, Regular)
    assert_eq(metadata.size, test_data.length().to_int64())
    
    // 手动清理
    remove(test_path)
  })
}

///|
/// 测试：文件不存在错误处理
test "afs file not found error" {
  @async.with_event_loop(fn(_) {
    let non_existent = temp_path("non_existent.txt")

    // 确保文件不存在
    assert_false(exists(non_existent))

    // 尝试读取不存在的文件应该抛出错误
    try {
      let _data = read_all(non_existent, None)
      assert_false(true, msg="Should have thrown error")
    } catch {
      _err => () // 期望的错误
    }
  })
}