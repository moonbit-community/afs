# AFS - Async Filesystem API for MoonBit

Easy-to-use, strongly-typed, cancellable, timeout-capable, atomically recoverable, and error-observable asynchronous filesystem API

## Features

- 🚀 **Asynchronous Non-blocking I/O** - Based on moonbitlang/async, supports high-concurrency file operations
- 🔒 **Strong Type Safety** - Complete type checking with compile-time error detection
- ⏰ **Timeout Control** - Built-in timeout mechanism to prevent infinite waiting
- 🚫 **Cancellable Operations** - Support for task cancellation with graceful interrupt handling
- ⚛️ **Atomic Operations** - Atomic file writes with crash safety
- 📊 **Observable Errors** - Rich error types with detailed error information
- 🔧 **Retry Mechanism** - Built-in retry strategies for handling unstable operations like network I/O
- 🌐 **UTF-8 Support** - Native UTF-8 encoding support
- 📁 **Concurrent Copying** - Efficient concurrent directory copying
- 🔄 **Unified Interface** - Reader/Writer trait unified abstraction

## Quick Start

### Install Dependencies

```bash
moon update && moon add moonbitlang/async
```

Add to `moon.mod.json`:

```json
{
  "preferred-target": "native"
}
```

Add to `moon.pkg.json`:

```json
{
  "import": [
    "allwefantasy/afs",
    "moonbitlang/async"
  ]
}
```

### Basic Usage

```moonbit
fn main {
  @async.with_event_loop(fn(_) {
    // Write to file
    @afs.write_all(b"hello.txt", b"Hello, AFS!")
    
    // Read from file
    let content = @afs.read_all(b"hello.txt", None)
    println(@afs.utf8_to_string(content[:]))
    
    // Check if file exists
    if @afs.exists(b"hello.txt") {
      println("File exists")
    }
    
    // Get file metadata
    let metadata = @afs.stat(b"hello.txt")
    println("File size: \{metadata.size} bytes")
    
    // Cleanup
    @afs.remove(b"hello.txt")
  })
}
```

## Core API

### Basic File Operations

- `write_all(path, data)` - Write to file
- `read_all(path, max?)` - Read from file
- `exists(path)` - Check if file exists
- `stat(path)` - Get file metadata
- `remove(path)` - Delete file
- `remove_all(path)` - Recursively delete directory

### Advanced Operations

- `atomic_write(path, producer)` - Atomic write (crash-safe)
- `copy_file(src, dst)` - Copy file
- `copy_tree(ctx, src, dst)` - Concurrent directory tree copying
- `with_fs_timeout(ms, operation)` - Operation with timeout
- `with_fs_retry(method, operation)` - Operation with retry

### Directory Operations

- `ensure_dir(path)` - Ensure directory exists (mkdir -p)
- `open_dir(path)` - Open directory
- `read_dir_all(dir)` - Read directory contents

## Testing

Run tests:

```bash
moon test --target native
```

## License

Apache-2.0