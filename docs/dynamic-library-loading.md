# 动态库加载与符号解析（Linux 简要说明）

本文档说明 Linux 下动态库（.so）的加载与符号解析，以及 ltask 与扩展库（如 rust.so）如何正确协同。便于理解「为什么 rust.so 需要链接 ltask.so」以及 rpath 的作用。

---

## 1. 基本概念

### 1.1 动态库（shared object / .so）

- 动态库是编译好的、可在运行时被多个程序（或同一程序多次）加载的代码与数据。
- 在 ltask 项目中：
  - **ltask.so**：C 核心，提供 `send_integer_message`、`send_message` 等符号。
  - **rust.so**：Rust 编写的扩展，内部会**调用**这些 C 函数，因此需要能在运行时**找到**它们。

### 1.2 符号（symbol）

- 符号即函数名、变量名等，在 .so 里要么是**定义的**（实现在这里），要么是**未定义的**（需要从别的 .so 或可执行文件里解析）。
- 例如：`send_integer_message` 在 **ltask.so** 里**有定义**，在 **rust.so** 里是**未定义引用**（Rust 侧只是声明并调用）。

### 1.3 动态链接器（dynamic linker）

- 负责在**加载**某个 .so 或可执行文件时，把其中所有「未定义符号」解析成实际地址。
- 解析时会在「该模块声明的依赖」以及（视情况）「已加载的全局符号」里查找；**不会**自动去「进程里已加载但未声明依赖的其它 .so」里找（详见下文）。

---

## 2. 加载时发生了什么

### 2.1 谁加载、按什么顺序

- 进程启动时，先加载**可执行文件**（例如 `lua`），再按它的 **DT_NEEDED** 列表依次加载其依赖的 .so。
- 之后，当代码调用 `dlopen("xxx.so", ...)` 时，动态链接器会：
  1. 加载 **xxx.so**；
  2. 再按 xxx.so 的 **DT_NEEDED** 加载它声明的依赖；
  3. 在「xxx.so + 其 DT_NEEDED 链上的所有 .so」里解析 xxx.so 的未定义符号。

Lua 的 `package.loadlib("path/to/xxx.so", "luaopen_xxx")` 底层就是 `dlopen`。

### 2.2 关键点：解析范围

- 对 **rust.so** 来说，动态链接器**只**会在下面这些地方为 rust.so 解析未定义符号：
  1. **rust.so 自身**；
  2. **rust.so 的 DT_NEEDED 里列出的 .so**（以及这些 .so 的 DT_NEEDED，递归）；
  3. 若 dlopen 时用了 **RTLD_GLOBAL**，则还有「当前进程已加载且为全局可见」的 .so。

如果 **ltask.so 既不在 rust.so 的 DT_NEEDED 里，也没有以 RTLD_GLOBAL 加载**，那么即使进程里已经加载了 ltask.so，链接器也**不会**用 ltask.so 来解析 rust.so 里的 `send_integer_message`，从而报 **undefined symbol**。

---

## 3. 符号可见性：RTLD_LOCAL 与 RTLD_GLOBAL

### 3.1 dlopen 的两种常见模式

- **RTLD_LOCAL**（常见默认）：该 .so 里的符号**只**给「之后加载的、且声明了依赖它的 .so」用；不会放进「全局符号表」给其它无关 .so 用。
- **RTLD_GLOBAL**：该 .so 的符号会加入全局符号表，之后任何 dlopen 进来的 .so 都能用来解析自己的未定义符号。

### 3.2 Lua 一般怎么加载 C 模块

- Lua 的 C 模块加载（loadlib）通常对应 **dlopen(..., RTLD_LOCAL)**（或等价行为）。
- 因此：
  - 先 `require "ltask"` 加载的 **ltask.so** 的符号是 **LOCAL** 的；
  - 后 `require "rust.sqlx"` 加载 **rust.so** 时，动态链接器**不会**用已加载的 ltask.so 来解析 rust.so 的未定义符号，因为 ltask 不是「rust.so 的依赖」，也不是「全局可见」。

所以单靠「先加载 ltask.so」无法解决 rust.so 的 undefined symbol，必须让 **rust.so 显式依赖 ltask.so**（见下一节）。

---

## 4. 声明依赖：DT_NEEDED 与「链接时」的 -lltask

### 4.1 DT_NEEDED 是什么

- 每个 .so 里有一张「依赖表」，记录它依赖哪些其它 .so 的文件名；在 ELF 里对应 **DT_NEEDED**。
- 生成这张表的是**链接器**（在**编译/链接 rust.so 时**），不是运行时。

### 4.2 链接 rust.so 时加上 ltask.so

- 在构建 rust.so 时加上对 **ltask.so** 的链接（例如 `-L... -l:ltask.so` 或 `rustc-link-lib=dylib:+verbatim=ltask.so`），链接器会：
  1. 在 rust.so 的 ELF 里写入 **DT_NEEDED ltask.so**；
  2. 保证 rust.so 里对 `send_integer_message` 等的引用，在**加载时**由 ltask.so 提供。

这样，当 Lua 后来 `dlopen("rust.so")` 时：

1. 动态链接器加载 rust.so；
2. 发现 DT_NEEDED 里有 ltask.so，于是去加载 ltask.so（若尚未加载则加载，若已加载则复用）；
3. 在 **rust.so + ltask.so** 的符号中解析 rust.so 的未定义符号，从而找到 `send_integer_message` 等。

这就是「在 build.rs 里对 Linux 增加对 ltask.so 的链接」能修复 undefined symbol 的原因。

### 4.3 和「先 require ltask」的关系

- 若先执行了 `require "ltask"`，ltask.so 可能已经被加载进进程；再加载 rust.so 时，因为 rust.so 的 DT_NEEDED 里有 ltask.so，动态链接器会**直接复用**已加载的 ltask.so，不会重复加载。
- 若从未 require ltask，只要 rust.so 依赖 ltask.so，加载 rust.so 时链接器也会**先**加载 ltask.so，再解析 rust.so 的符号。  
因此，**关键不是「谁先 require」，而是「rust.so 是否在链接时声明了对 ltask.so 的依赖」**。

---

## 5. 运行时找库：搜索顺序与 rpath

### 5.1 加载 rust.so 时，链接器要找到 ltask.so

- rust.so 的 DT_NEEDED 里只有**文件名**（如 `ltask.so`），没有绝对路径。
- 动态链接器按一定**搜索顺序**找这个文件，常见顺序大致为：
  1. 可执行文件里记录的 **RPATH / RUNPATH**（若存在）；
  2. **LD_LIBRARY_PATH** 中的目录；
  3. **RUNPATH**（若存在，与 1 在部分系统上顺序可能不同）；
  4. 系统默认库目录（如 /lib, /usr/lib 等）。

ltask.so 通常不在系统目录，因此需要 **RPATH/RUNPATH** 或 **LD_LIBRARY_PATH** 指向其所在目录。

### 5.2 RPATH / RUNPATH 与 $ORIGIN

- **RPATH / RUNPATH** 是写在 .so 或可执行文件里的「库搜索路径」列表，在**链接**时由我们指定（例如 `-Wl,-rpath,'$ORIGIN/..'`）。
- **$ORIGIN** 表示「当前 .so 所在目录」：
  - 若 rust.so 在 `.../ltask/luaclib/rust.so`，则 `$ORIGIN` = `.../ltask/luaclib`；
  - `$ORIGIN/..` = `.../ltask`，即仓库根目录，ltask.so 若放在根目录，就能被找到。

这样无需设置 LD_LIBRARY_PATH，只要 rust.so 和 ltask.so 的相对位置符合预期，就能在运行时找到 ltask.so。

### 5.3 本项目中 build.rs 的写法

- `-Wl,-rpath,$ORIGIN/..`：把「当前 .so 的上一级目录」写入 rust.so 的 rpath；
- 部署时保持：**rust.so 在 luaclib/**，**ltask.so 在上一级目录**（例如项目根），即可正常加载。

---

## 6. ltask + rust.so 的完整流程小结

| 阶段 | 说明 |
|------|------|
| **构建 ltask.so** | `make` 生成 `ltask.so`，其中实现并导出 `send_integer_message`、`send_message`。 |
| **构建 rust.so** | 链接时加上 `-L<ltask_dir> -l:ltask.so`，生成 DT_NEEDED ltask.so；并加 `-Wl,-rpath,$ORIGIN/..`，便于运行时找到 ltask.so。 |
| **运行 Lua** | 可执行文件为 `lua`（或你的启动器），一般不依赖 ltask.so。 |
| **require "ltask"** | Lua 通过 loadlib 加载 ltask.so（通常 RTLD_LOCAL），ltask.so 被加载进进程。 |
| **require "rust.sqlx"** | Lua 通过 loadlib 加载 luaclib/rust.so。 |
| **加载 rust.so** | 动态链接器看到 DT_NEEDED ltask.so，按 rpath 找到 ltask.so 并加载（或复用已加载的）；在 ltask.so 中解析 rust.so 的 `send_integer_message` 等，解析成功，不再报 undefined symbol。 |

---

## 7. 常用调试命令（便于自查）

- 看某 .so 导出了哪些符号（例如是否包含 `send_integer_message`）：
  ```bash
  nm -D ltask.so | grep send_integer_message
  ```
- 看某 .so 依赖了哪些其它 .so（是否有 ltask.so）：
  ```bash
  ldd luaclib/rust.so
  ```
  或：
  ```bash
  readelf -d luaclib/rust.so | grep NEEDED
  ```
- 看某 .so 的 rpath/runpath：
  ```bash
  readelf -d luaclib/rust.so | grep -E 'RPATH|RUNPATH'
  ```

---

## 8. 参考：本项目中的相关配置

- **ltask.so** 中导出 `send_integer_message` / `send_message` 的代码：`src/ltask_ext.c`。
- **rust.so 链接 ltask.so 与 rpath**：`3rd/lrust/crates/libs/lib-lualib/build.rs`（Linux 分支）。
- 可选环境变量 **LTASK_DIR**：构建 rust.so 时若 ltask.so 不在默认相对路径，可设置 `LTASK_DIR` 为包含 ltask.so 的目录，build.rs 会将该目录作为 `-L` 的搜索路径。

以上内容应能帮助理解「动态库加载与符号解析」在本项目中的行为，以及为何必须让 rust.so 链接 ltask.so 并设置 rpath。
