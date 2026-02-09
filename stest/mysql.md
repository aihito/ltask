没问题！既然你已经通过命令行连接到了 MySQL（端口 `23306`），你可以按照以下步骤执行 SQL 语句。

由于你目前的登录身份是 `root`，你拥有最高权限来完成这些操作。

---

### 1. 创建用户并授权

首先，我们创建一个名为 `hito` 的用户，并授予其对 `game` 数据库的所有权限。

```sql
-- 创建用户 hito，密码为 123
CREATE USER 'hito'@'%' IDENTIFIED BY '123';

-- 创建数据库 game
CREATE DATABASE IF NOT EXISTS game CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 授予 hito 用户对 game 数据库的所有权限
GRANT ALL PRIVILEGES ON game.* TO 'hito'@'%';

-- 刷新权限使配置生效
FLUSH PRIVILEGES;

```

---

### 2. 创建数据表 `role`

接下来，我们切换到 `game` 数据库并创建一个角色表。这里我定义了基础的 ID、角色名、职业、等级和创建时间。

```sql
USE game;

CREATE TABLE IF NOT EXISTS role (
    id INT AUTO_INCREMENT PRIMARY KEY COMMENT '角色唯一ID',
    role_name VARCHAR(50) NOT NULL COMMENT '角色名称',
    job_type ENUM('Warrior', 'Mage', 'Archer') DEFAULT 'Warrior' COMMENT '职业',
    level INT DEFAULT 1 COMMENT '等级',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间'
) ENGINE=InnoDB;

```

---

### 3. 插入示例数据

往 `role` 表里塞入几个“路人甲”角色：

```sql
INSERT INTO role (role_name, job_type, level) VALUES 
('剑圣', 'Warrior', 99),
('甘道夫', 'Mage', 50),
('后羿', 'Archer', 15);

```

---

### 4. 验证结果

你可以执行以下语句看看数据是否进去了：

```sql
SELECT * FROM role;

```

---

### 总结与后续

你现在已经拥有了一个数据库 `game` 和一个拥有权限的用户 `hito`。

**小贴士：**

* 如果你是在本地测试，`'hito'@'%'` 表示允许该用户从任何 IP 连接。如果你希望更安全，可以改为 `'hito'@'localhost'`。
* 下次登录时，你可以直接使用新用户：
`mysql --protocol=tcp -h 127.0.0.1 -P 23306 -u hito -p123`

需要我帮你写一段 Python 或 Java 代码来连接这个新创建的 `game` 数据库吗？