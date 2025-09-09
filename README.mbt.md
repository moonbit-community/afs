# AFS - Async Filesystem API for MoonBit

极易用、强类型、可取消、可超时、原子可恢复、错误可观测的异步文件系统 API

## 特性

- 🚀 **异步非阻塞 I/O** - 基于 moonbitlang/async，支持高并发文件操作
- 🔒 **强类型安全** - 完整的类型检查，编译期错误发现 
- ⏰ **超时控制** - 内置超时机制，避免操作无限等待
- 🚫 **可取消操作** - 支持任务取消，优雅处理中断
- ⚛️ **原子操作** - 原子文件写入，崩溃安全
- 📊 **错误可观测** - 丰富的错误类型和详细错误信息
- 🔧 **重试机制** - 内置重试策略，处理网络等不稳定操作
- 🌐 **UTF-8 支持** - 原生 UTF-8 编码支持
- 📁 **并发拷贝** - 高效的并发目录拷贝
- 🔄 **统一接口** - Reader/Writer trait 统一抽象

## 快速开始

### 安装依赖

```bash
moon update && moon add moonbitlang/async
```

在 `moon.mod.json` 中添加：

```json
{
  "preferred-target": "native"
}
```

在 `moon.pkg.json` 中添加：

```json
{
  "import": [
    "allwefantasy/afs",
    "moonbitlang/async"
  ]
}
```

### 基本使用

```moonbit
fn main {
  @async.with_event_loop(fn(_) {
    // 写入文件
    @afs.write_all(b"hello.txt", b"Hello, AFS!")
    
    // 读取文件
    let content = @afs.read_all(b"hello.txt", None)
    println(@afs.utf8_to_string(content[:]))
    
    // 检查文件存在
    if @afs.exists(b"hello.txt") {
      println("文件存在")
    }
    
    // 获取文件元数据
    let metadata = @afs.stat(b"hello.txt")
    println("文件大小: \{metadata.size} 字节")
    
    // 清理
    @afs.remove(b"hello.txt")
  })
}
```

## 核心 API

### 基本文件操作

- `write_all(path, data)` - 写入文件
- `read_all(path, max?)` - 读取文件
- `exists(path)` - 检查文件是否存在
- `stat(path)` - 获取文件元数据
- `remove(path)` - 删除文件
- `remove_all(path)` - 递归删除目录

### 高级操作

- `atomic_write(path, producer)` - 原子写入（崩溃安全）
- `copy_file(src, dst)` - 拷贝文件
- `copy_tree(ctx, src, dst)` - 并发拷贝目录树
- `with_fs_timeout(ms, operation)` - 带超时的操作
- `with_fs_retry(method, operation)` - 带重试的操作

### 目录操作

- `ensure_dir(path)` - 确保目录存在（mkdir -p）
- `open_dir(path)` - 打开目录
- `read_dir_all(dir)` - 读取目录内容

## 测试

运行测试：

```bash
moon test --target native
```

## 许可证

Apache-2.0