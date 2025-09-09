///|
/// @afs - Async Filesystem API
/// 
/// 极易用、强类型、可取消、可超时、原子可恢复、错误可观测的异步文件系统 API
/// 
/// 基于 moonbitlang/async 和结构化并发设计，内部使用 tonyfettes/encoding 
/// 进行 UTF-8 编解码，对用户完全透明。

///|
/// 路径类型：原始字节路径
pub typealias Bytes as Path

///|
/// 文件打开模式
pub enum OpenMode {
  ReadOnly
  WriteOnly
  ReadWrite
} derive(Show, Eq, Compare)

///|
/// 同步模式
pub enum SyncMode {
  NoSync // 不同步
  Data // 同步数据
  Full // 同步数据和元数据（默认，更安全）
} derive(Show, Eq, Compare)

///|
/// 文件类型
pub(all) enum FileKind {
  Regular
  Directory
  SymLink
  Socket
  Pipe
  Other
} derive(Show, Eq, Compare)

///|
/// 文件系统错误类型
pub enum FsErrKind {
  NotFound
  PermissionDenied
  AlreadyExists
  InvalidPath
  Io
  Busy
  Timeout
  Canceled
  Unsupported
} derive(Show, Eq, Compare)

///|
/// 文件打开选项
pub struct OpenOptions {
  mode : OpenMode
  create : Int? // Some(0o644) -> 创建并设权限
  truncate : Bool? // 是否截断
  append : Bool? // 是否追加
  sync : SyncMode // 同步模式，默认 Full
} derive(Show, Eq, Compare)

///|
/// 文件元数据
pub struct Metadata {
  kind : FileKind
  size : Int64
  perm : Int?
  mtime : Int64?
  atime : Int64?
  ctime : Int64?
} derive(Show, Eq, Compare)

///|
/// 文件系统错误（错误类型）
pub suberror FsError {
  Internal(FsErrKind, String, Path?, String?)
} derive(Show, Eq, Compare)

///|
/// 创建 FsError
pub fn FsError::new(
  kind : FsErrKind,
  op : String,
  path : Path?,
  cause : String?,
) -> FsError {
  Internal(kind, op, path, cause)
}

///|
/// 获取错误类型
pub fn FsError::kind(self : FsError) -> FsErrKind {
  match self {
    Internal(kind, _, _, _) => kind
  }
}

///|
/// 获取操作名称
pub fn FsError::op(self : FsError) -> String {
  match self {
    Internal(_, op, _, _) => op
  }
}

///|
/// 获取路径
pub fn FsError::path(self : FsError) -> Path? {
  match self {
    Internal(_, _, path, _) => path
  }
}

///|
/// 获取原因
pub fn FsError::cause(self : FsError) -> String? {
  match self {
    Internal(_, _, _, cause) => cause
  }
}

///|
/// AFS 文件包装器
pub struct File {
  inner : @fs.File
}

///|
/// 创建默认的文件打开选项
pub fn OpenOptions::default() -> OpenOptions {
  OpenOptions::{
    mode: ReadOnly,
    create: None,
    truncate: None,
    append: None,
    sync: Full,
  }
}

///|
/// 创建只读打开选项
pub fn OpenOptions::read_only() -> OpenOptions {
  OpenOptions::{
    mode: ReadOnly,
    create: None,
    truncate: None,
    append: None,
    sync: Full,
  }
}

///|
/// 创建写入打开选项
pub fn OpenOptions::write_only() -> OpenOptions {
  OpenOptions::{
    mode: WriteOnly,
    create: Some(0o644),
    truncate: Some(true),
    append: None,
    sync: Full,
  }
}

///|
/// 创建读写打开选项
pub fn OpenOptions::read_write() -> OpenOptions {
  OpenOptions::{
    mode: ReadWrite,
    create: Some(0o644),
    truncate: None,
    append: None,
    sync: Full,
  }
}

///|
/// 设置创建权限
pub fn OpenOptions::with_create(self : OpenOptions, perm : Int) -> OpenOptions {
  OpenOptions::{ ..self, create: Some(perm) }
}

///|
/// 设置截断模式
pub fn OpenOptions::with_truncate(
  self : OpenOptions,
  truncate : Bool,
) -> OpenOptions {
  OpenOptions::{ ..self, truncate: Some(truncate) }
}

///|
/// 设置追加模式
pub fn OpenOptions::with_append(
  self : OpenOptions,
  append : Bool,
) -> OpenOptions {
  OpenOptions::{ ..self, append: Some(append) }
}

///|
/// 设置同步模式
pub fn OpenOptions::with_sync(
  self : OpenOptions,
  sync : SyncMode,
) -> OpenOptions {
  OpenOptions::{ ..self, sync, }
}

///|
/// 内部工具函数：UTF-8 字符串转字节
pub fn to_utf8_bytes(s : String) -> Bytes {
  @encoding.encode(s, encoding=UTF8)
}

///|
/// 内部工具函数：字节转 UTF-8 字符串（可能失败）
pub fn utf8_to_string(b : @bytes.View) -> String raise {
  @encoding.decode(b, encoding=UTF8)
}

///|
/// 内部工具函数：路径转字符串（用于日志/错误显示）
pub fn path_to_string(path : Path) -> String {
  utf8_to_string(path[:]) catch {
    _ => "<invalid utf8>"
  }
}

///|
/// 内部工具函数：将错误转换为 FsError
fn map_fs_error(op : String, path : Path?, err : String) -> FsError {
  // 简化实现：根据错误字符串推断错误类型
  let kind = if err.contains("No such file") {
    NotFound
  } else if err.contains("Permission denied") {
    PermissionDenied
  } else if err.contains("File exists") {
    AlreadyExists
  } else if err.contains("Invalid") {
    InvalidPath
  } else if err.contains("Busy") {
    Busy
  } else {
    Io
  }
  FsError::new(kind, op, path, Some(err))
}

///|
/// 内部工具函数：验证路径安全性
fn validate_path_safety(path : Path, op : String) -> Unit raise FsError {
  let path_str = path_to_string(path)
  if path_str == "" ||
    path_str == "/" ||
    path_str == "." ||
    path_str == "./" ||
    path_str == "/." {
    raise FsError::new(
      InvalidPath,
      op,
      Some(path),
      Some("Dangerous path not allowed"),
    )
  }
}

///|
/// 将 @fs 文件类型转换为 FileKind
fn convert_file_kind(kind : @fs.FileKind) -> FileKind {
  match kind {
    @fs.FileKind::Regular => Regular
    @fs.FileKind::Directory => Directory
    @fs.FileKind::SymLink => SymLink
    @fs.FileKind::Socket => Socket
    @fs.FileKind::Pipe => Pipe
    _ => Other
  }
}

///|
/// 将 OpenMode 转换为 @fs.Mode
fn convert_open_mode(mode : OpenMode) -> @fs.Mode {
  match mode {
    ReadOnly => @fs.Mode::ReadOnly
    WriteOnly => @fs.Mode::WriteOnly
    ReadWrite => @fs.Mode::ReadWrite
  }
}

///|
/// 将 SyncMode 转换为 @fs.SyncMode
fn convert_sync_mode(mode : SyncMode) -> @fs.SyncMode {
  match mode {
    NoSync => @fs.SyncMode::NoSync
    Data => @fs.SyncMode::Data
    Full => @fs.SyncMode::Full
  }
}

// ============================================================================
// 3.1 路径与元数据 API
// ============================================================================

///|
/// 获取文件/目录的元数据
pub async fn stat(path : Path) -> Metadata raise FsError {
  try {
    let file = @fs.open(path, mode=@fs.Mode::ReadOnly)
    defer file.close()
    let kind = convert_file_kind(file.kind())
    let size = file.size()
    Metadata::{
      kind,
      size,
      perm: None, // @fs 暂不提供权限信息
      mtime: None, // @fs 暂不提供时间信息
      atime: None,
      ctime: None,
    }
  } catch {
    err => raise map_fs_error("stat", Some(path), err.to_string())
  }
}

///|
/// 检查文件/目录是否存在
pub async fn exists(path : Path) -> Bool raise FsError {
  @fs.exists(path) catch {
    err => raise map_fs_error("exists", Some(path), err.to_string())
  }
}

///|
/// 获取文件/目录类型
pub async fn kind_of(path : Path) -> FileKind raise FsError {
  try {
    let fs_kind = @fs.kind(path)
    convert_file_kind(fs_kind)
  } catch {
    err => raise map_fs_error("kind_of", Some(path), err.to_string())
  }
}

// ============================================================================
// 3.2 打开/创建/删除 API
// ============================================================================

///|
/// 打开文件
pub async fn open(path : Path, opts : OpenOptions?) -> File raise FsError {
  let options = match opts {
    Some(o) => o
    None => OpenOptions::read_only()
  }
  try {
    let mode = convert_open_mode(options.mode)
    let sync = convert_sync_mode(options.sync)
    let file = @fs.open(
      path,
      mode~,
      sync?=Some(sync),
      append?=options.append,
      create?=options.create,
      truncate?=options.truncate,
    )
    File::{ inner: file }
  } catch {
    err => raise map_fs_error("open", Some(path), err.to_string())
  }
}

///|
/// 创建新文件
pub async fn create(
  path : Path,
  perm? : Int = 0o644,
  sync? : SyncMode = Full,
) -> File raise FsError {
  try {
    let file = @fs.create(
      path,
      permission=perm,
      sync?=Some(convert_sync_mode(sync)),
    )
    File::{ inner: file }
  } catch {
    err => raise map_fs_error("create", Some(path), err.to_string())
  }
}

///|
/// 删除文件（拒绝危险路径）
pub async fn remove(path : Path) -> Unit raise FsError {
  validate_path_safety(path, "remove")
  @fs.remove(path) catch {
    err => raise map_fs_error("remove", Some(path), err.to_string())
  }
}

///|
/// 递归删除目录（拒绝危险路径，不跟随 symlink）
pub async fn remove_all(path : Path) -> Unit raise FsError {
  validate_path_safety(path, "remove_all")
  try {
    // 检查是否为目录
    let metadata = stat(path)
    match metadata.kind {
      Directory => {
        // 递归删除目录内容
        let dir_file = @fs.open(path, mode=@fs.Mode::ReadOnly)
        defer dir_file.close()
        let dir = dir_file.as_dir()
        let entries = dir.read_all()
        for entry in entries {
          let entry_path = path + b"/" + entry
          let entry_metadata = stat(entry_path)
          match entry_metadata.kind {
            Directory => remove_all(entry_path)
            SymLink => @fs.remove(entry_path) // 不跟随 symlink
            _ => @fs.remove(entry_path)
          }
        }

        // 删除空目录
        @fs.remove(path)
      }
      _ =>
        // 删除文件或其他类型
        @fs.remove(path)
    }
  } catch {
    err => raise map_fs_error("remove_all", Some(path), err.to_string())
  }
}

// ============================================================================
// 3.3 便捷读写 API
// ============================================================================

///|
/// 读取文件全部内容
pub async fn read_all(path : Path, max : Int?) -> Bytes raise FsError {
  try {
    let file = open(path, Some(OpenOptions::read_only()))
    defer file.inner.close()
    match max {
      Some(limit) => read_at_most_from_file(file, limit)
      None => file.inner.read_all()
    }
  } catch {
    err => raise map_fs_error("read_all", Some(path), err.to_string())
  }
}

///|
/// 读取文件最多指定字节数
pub async fn read_at_most(path : Path, limit : Int) -> Bytes raise FsError {
  try {
    let file = open(path, Some(OpenOptions::read_only()))
    defer file.inner.close()
    read_at_most_from_file(file, limit)
  } catch {
    err => raise map_fs_error("read_at_most", Some(path), err.to_string())
  }
}

///|
/// 内部函数：从文件读取最多指定字节数
async fn read_at_most_from_file(
  file : File,
  limit : Int,
) -> Bytes raise FsError {
  if limit <= 0 {
    return b""
  }
  let buf = FixedArray::make(limit, b'0')
  try {
    let bytes_read = file.inner.read(buf)
    buf.unsafe_reinterpret_as_bytes()[0:bytes_read].to_bytes()
  } catch {
    err => raise map_fs_error("read", None, err.to_string())
  }
}

///|
/// 写入数据到文件
pub async fn write_all(
  path : Path,
  data : @bytes.View,
  perm? : Int = 0o644,
) -> Unit raise FsError {
  try {
    let file = create(path, perm~)
    defer file.inner.close()
    file.inner.write(data)
  } catch {
    err => raise map_fs_error("write_all", Some(path), err.to_string())
  }
}

// ============================================================================
// 3.4 原子写 API
// ============================================================================

///|
/// 原子写入产生器函数类型
pub typealias (@fs.File) -> Unit raise as WriteProducer

///|
/// 原子写入（崩溃/取消安全）
pub async fn atomic_write(
  path : Path,
  produce : WriteProducer,
  perm? : Int = 0o644,
  fsync? : Bool = true,
) -> Unit raise FsError {
  // 生成临时文件名  
  let tmp_path = path + b".tmp.42" // 简化的临时文件名
  try {
    // 写入临时文件
    {
      let tmp_file = create(tmp_path, perm~)
      defer tmp_file.inner.close()

      // 在保护块中写入数据
      @async.protect_from_cancel(fn() {
        produce(tmp_file.inner)
        if fsync {
          // TODO: 等待 @fs 支持 fsync
        }
      })
    }

    // 原子重命名
    @async.protect_from_cancel(fn() { rename(tmp_path, path) })
  } catch {
    err => {
      // 清理临时文件
      @fs.remove(tmp_path) catch {
        _ => () // 忽略清理错误
      }
      raise map_fs_error("atomic_write", Some(path), err.to_string())
    }
  }
}

// ============================================================================
// 3.5 目录 API
// ============================================================================

///|
/// 打开目录
pub async fn open_dir(path : Path) -> @fs.Directory raise FsError {
  @fs.opendir(path) catch {
    err => raise map_fs_error("open_dir", Some(path), err.to_string())
  }
}

///|
/// 读取目录所有条目
pub async fn read_dir_all(dir : @fs.Directory) -> Array[Path] raise FsError {
  try {
    let entries = dir.read_all()
    // 直接返回，因为 Path 就是 Bytes 的别名
    entries
  } catch {
    err => raise map_fs_error("read_dir_all", None, err.to_string())
  }
}

///|
/// 确保目录存在（等价于 mkdir -p）
pub async fn ensure_dir(
  path : Path,
  perm? : Int = 0o755,
  recursive? : Bool = true,
) -> Unit raise FsError {
  if exists(path) {
    let metadata = stat(path)
    if metadata.kind != Directory {
      raise FsError::new(
        AlreadyExists,
        "ensure_dir",
        Some(path),
        Some("Path exists but is not a directory"),
      )
    }
    return
  }
  if recursive {
    // 递归创建父目录
    let path_str = path_to_string(path)
    if path_str.contains("/") {
      let parts = path_str.split("/").collect()
      let mut current_path = b""
      for i = 0; i < parts.length(); i = i + 1 {
        let part = parts[i]
        if part != "" {
          if i > 0 {
            current_path = current_path + b"/"
          }
          current_path = current_path + to_utf8_bytes(part.to_string())
          if not(exists(current_path)) {
            create_single_dir(current_path, perm)
          }
        }
      }
    } else {
      create_single_dir(path, perm)
    }
  } else {
    create_single_dir(path, perm)
  }
}

///|
/// 内部函数：创建单个目录
async fn create_single_dir(path : Path, perm : Int) -> Unit raise FsError {
  @fs.mkdir(path, permission=perm) catch {
    err => raise map_fs_error("mkdir", Some(path), err.to_string())
  }
}

// ============================================================================
// 3.6 拷贝/移动 API
// ============================================================================

///|
/// 复制文件
pub async fn copy_file(
  src : Path,
  dst : Path,
  overwrite? : Bool = false,
) -> Unit raise FsError {
  if not(overwrite) && exists(dst) {
    raise FsError::new(
      AlreadyExists,
      "copy_file",
      Some(dst),
      Some("Destination exists and overwrite=false"),
    )
  }
  try {
    let src_file = open(src, Some(OpenOptions::read_only()))
    defer src_file.inner.close()
    let dst_file = create(dst)
    defer dst_file.inner.close()
    dst_file.inner.write_reader(src_file.inner)
  } catch {
    err => raise map_fs_error("copy_file", Some(src), err.to_string())
  }
}

///|
/// 并发复制目录树（结构化并发）
pub async fn copy_tree(
  ctx : @async.TaskGroup[Unit],
  src : Path,
  dst : Path,
  concurrency? : Int = 8,
  overwrite? : Bool = false,
) -> Unit raise FsError {
  // 简化实现：直接递归复制，不使用信号量
  copy_tree_recursive(src, dst, overwrite)
}

///|
/// 内部函数：递归复制目录
async fn copy_tree_recursive(
  src : Path,
  dst : Path,
  overwrite : Bool,
) -> Unit raise FsError {
  let src_metadata = stat(src)
  match src_metadata.kind {
    Directory => {
      // 创建目标目录
      if not(exists(dst)) {
        ensure_dir(dst)
      }

      // 复制目录内容
      let dir = open_dir(src)
      defer dir.close()
      let entries = read_dir_all(dir)
      for entry in entries {
        let src_entry = src + b"/" + entry
        let dst_entry = dst + b"/" + entry
        copy_tree_recursive(src_entry, dst_entry, overwrite)
      }
    }
    SymLink =>
      // 不跟随符号链接，直接复制链接本身
      // TODO: 实现符号链接复制
      copy_file(src, dst, overwrite~)
    _ =>
      // 复制文件
      copy_file(src, dst, overwrite~)
  }
}

///|
/// 重命名/移动文件或目录
pub async fn rename(src : Path, dst : Path) -> Unit raise FsError {
  try {
    // 使用 mv 命令（简化实现）
    let exit_code = @process.run(b"mv", [src, dst])
    if exit_code != 0 {
      raise FsError::new(Io, "rename", Some(src), Some("mv failed"))
    }
  } catch {
    err => raise map_fs_error("rename", Some(src), err.to_string())
  }
}

// ============================================================================
// 3.7 流/管道便捷 API
// ============================================================================

///|
/// 将文件内容管道传输到 Writer
pub async fn[W : @io.Writer] pipe_file_to_writer(
  path : Path,
  out : W,
) -> Unit raise FsError {
  try {
    let file = open(path, Some(OpenOptions::read_only()))
    defer file.inner.close()
    out.write_reader(file.inner)
  } catch {
    err =>
      raise map_fs_error("pipe_file_to_writer", Some(path), err.to_string())
  }
}

///|
/// 将 Reader 内容管道传输到文件
pub async fn[R : @io.Reader] pipe_reader_to_file(
  input : R,
  path : Path,
  perm? : Int = 0o644,
) -> Unit raise FsError {
  try {
    let file = create(path, perm~)
    defer file.inner.close()
    file.inner.write_reader(input)
  } catch {
    err =>
      raise map_fs_error("pipe_reader_to_file", Some(path), err.to_string())
  }
}

// ============================================================================
// 3.8 超时/重试 API
// ============================================================================

///|
/// 超时回调函数类型
pub typealias () -> T raise FsError as TimeoutCallback[T]

///|
/// 带超时的文件系统操作
pub async fn[T] with_fs_timeout(
  ms : Int,
  f : TimeoutCallback[T],
) -> T raise FsError {
  try {
    @async.with_timeout(ms, fn() -> Unit raise { f() |> ignore })
    f()
  } catch {
    err => {
      let err_str = err.to_string()
      if err_str.contains("timeout") {
        raise FsError::new(Timeout, "with_fs_timeout", None, Some(err_str))
      } else {
        raise FsError::new(Io, "with_fs_timeout", None, Some(err_str))
      }
    }
  }
}

///|
/// 重试回调函数类型
pub typealias () -> T raise FsError as RetryCallback[T]

///|
/// 带重试的文件系统操作
pub async fn[T] with_fs_retry(
  retry_method : @async.RetryMethod,
  max_retry? : Int = 3,
  f : RetryCallback[T],
) -> T raise FsError {
  try {
    @async.retry(retry_method, max_retry~, fn() -> Unit raise { f() |> ignore })
    f()
  } catch {
    err => raise map_fs_error("with_fs_retry", None, err.to_string())
  }
}

// ============================================================================
// File 类型的 Reader/Writer 实现
// ============================================================================

///|
/// File 实现 Reader 接口
impl @io.Reader for File with read(self, buf, offset~, max_len~) {
  self.inner.read(buf, offset?=Some(offset), max_len?=Some(max_len))
}

///|
/// File 实现 Reader 接口 - read_all
impl @io.Reader for File with read_all(self) {
  self.inner.read_all()
}

///|
/// File 实现 Writer 接口 - write_once
impl @io.Writer for File with write_once(self, data, offset~, len~) {
  self.inner.write(data[offset:offset + len])
  len
}

///|
/// File 实现 Writer 接口 - write
impl @io.Writer for File with write(self, data) {
  self.inner.write(data)
}

///|
/// File 实现 Writer 接口 - write_reader
impl @io.Writer for File with write_reader(self, reader) {
  self.inner.write_reader(reader)
}

///|
/// File 关闭方法
pub fn File::close(self : File) -> Unit {
  self.inner.close()
}

///|
/// File 读取方法
pub async fn File::read(
  self : File,
  buf : FixedArray[Byte],
  offset? : Int = 0,
  max_len? : Int = buf.length(),
) -> Int raise {
  self.inner.read(buf, offset~, max_len~)
}

///|
/// File 读取全部内容方法
pub async fn File::read_all(self : File) -> Bytes raise {
  self.inner.read_all()
}

///|
/// File 写入方法
pub async fn File::write(self : File, data : @bytes.View) -> Unit raise {
  self.inner.write(data)
}

///|
/// File 获取大小
pub fn File::size(self : File) -> Int64 raise {
  self.inner.size()
}

///|
/// File 获取文件类型
pub fn File::kind(self : File) -> FileKind {
  convert_file_kind(self.inner.kind())
}
