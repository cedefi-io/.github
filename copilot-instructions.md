# CeDeFi 项目编码规范

## Go 后端规范

### 命名约定
- **结构体、接口、类型别名**：使用 `PascalCase`（如 `UserService`、`OrderRepo`）
- **函数、方法、变量**：使用 `camelCase`（如 `getUserInfo`、`orderID`）
- **常量**：全大写蛇形（如 `MAX_RETRY_COUNT`、`DEFAULT_TIMEOUT`）
- **包名**：简短小写，单数形式（如 `model`、`service`、`util`）
- **私有成员**：小写开头表示包内可见（如 `privateFunc`）

### 项目架构约定
- **分层结构**：`controller` → `service` → `model/repository`，保持职责清晰
- **配置管理**：使用 Viper 统一加载 YAML，配置结构体放在 `config/` 包
- **错误处理**：
  - 底层错误使用 `fmt.Errorf` 包装上下文，向上传递
  - HTTP/gRPC 层统一转换为标准错误码
  - 避免吞噬错误，必要时记录日志再返回
- **日志规范**：
  - 统一使用 Zap，结构化字段（`zap.String()`、`zap.Error()` 等）
  - 日志级别：`Debug`（开发诊断）、`Info`（业务流程）、`Warn`（异常但可恢复）、`Error`（需人工介入）
  - 示例：`log.Logger.Info("order created", zap.String("orderID", id), zap.Int64("amount", amt))`

### 数据库与 ORM (GORM)
- **连接池**：设置合理的 `MaxIdleConns`、`MaxOpenConns`，避免资源浪费
- **事务管理**：使用 `tx := db.Begin()` + `defer` 确保 Commit/Rollback
- **查询优化**：
  - 避免 N+1 查询，使用 `Preload`/`Joins` 预加载关联
  - 索引字段需在 struct tag 中声明 `gorm:"index"`
  - 复杂查询考虑使用原生 SQL 或 `Raw()`
- **字段映射**：使用 `gorm` tag 明确列名、类型、约束

### Redis 缓存
- **键名规范**：统一前缀 + 业务模块 + 标识符（如 `cedefi:order:lock:{orderID}`）
- **过期时间**：所有缓存必须设置 TTL，避免内存泄漏
- **分布式锁**：使用 `go-redsync` 实现，注意设置合理超时与重试策略

### gRPC 服务
- **拦截器**：统一注册日志拦截器（记录请求/响应）、恢复拦截器（捕获 panic）
- **连接管理**：
  - 客户端使用长连接 + Keepalive + 退避重连策略
  - 服务端设置合理的 MaxConnectionAge 避免连接泄漏
- **错误码**：使用 gRPC 标准 Status Code（`codes.InvalidArgument`、`codes.Internal` 等）

### Kafka 消费者
- **消费组**：确保同一主题的消费者使用相同 Group ID
- **幂等性**：消费者逻辑必须支持重复消费（去重、状态机校验）
- **错误处理**：失败消息写入死信队列（DLQ）或重试队列，避免阻塞正常消费

### 并发与性能
- **Goroutine 管理**：使用 `sync.WaitGroup`、`context.Context` 控制生命周期，避免泄漏
- **并发限制**：使用工作池（如 `ants`）或 channel buffer 控制并发数
- **大数值计算**：使用 `shopspring/decimal` 避免浮点精度问题

### 代码质量
- **函数长度**：单个函数不超过 50 行，复杂逻辑拆分为子函数
- **注释规范**：
  - 导出函数必须有注释说明功能、参数、返回值
  - 复杂算法或业务逻辑添加行内注释
  - 使用 `// TODO:` 标记待完善内容
- **单元测试**：核心业务逻辑必须覆盖测试，使用 `testify` 断言库

---

## 前端规范（Vue 3 / Next.js）

### 命名约定
- **组件**：`PascalCase`（如 `UserProfile.vue`、`OrderList.tsx`）
- **函数、变量**：`camelCase`（如 `fetchUserData`、`orderStatus`）
- **常量**：`UPPER_SNAKE_CASE`（如 `API_BASE_URL`）
- **CSS 类名**：`kebab-case`（如 `.user-card`、`.order-item`）

### 代码风格
- **HTML**：优先使用语义化标签（`<header>`、`<main>`、`<section>`）
- **JavaScript/TypeScript**：
  - 使用 `const`/`let`，避免 `var`
  - 优先使用箭头函数、模板字符串、解构赋值
  - 异步操作使用 `async/await`，避免回调地狱

### 组件设计
- **单一职责**：组件只负责一个功能模块
- **Props 校验**：TypeScript 类型或 Vue PropTypes 严格定义
- **事件命名**：使用 `on` 前缀（如 `@onSubmit`、`@onCancel`）

### 状态管理
- **Vue**：使用 Pinia，模块化 store（按业务拆分）
- **Next.js**：优先使用 React Context 或轻量状态库

### API 调用
- **统一封装**：使用 Axios 实例，配置拦截器处理 Token、错误码
- **错误处理**：全局捕获网络错误，提示用户友好信息
- **Loading 状态**：异步操作显示加载指示器

### 代码质量
- **ESLint + Prettier**：强制代码格式化，提交前自动检查
- **注释**：复杂逻辑添加注释，避免过度注释显而易见的代码
- **无用代码**：及时删除注释掉的代码、未使用的导入

---

## 通用规范

### Git 提交
- **消息格式**：`<type>(<scope>): <subject>`
  - `feat`: 新功能
  - `fix`: Bug 修复
  - `refactor`: 代码重构
  - `docs`: 文档更新
  - `chore`: 构建/工具变更
- **示例**：`feat(order): add order cancellation API`

### 安全规范
- **敏感信息**：禁止硬编码密码、私钥，使用环境变量或密钥管理服务
- **输入校验**：所有用户输入必须校验（类型、长度、格式）
- **SQL 注入防护**：使用 ORM 参数化查询，避免拼接 SQL

### 文档
- **README**：每个服务包含启动指南、环境依赖、配置说明
- **API 文档**：使用 Swagger/OpenAPI 自动生成，保持同步更新
