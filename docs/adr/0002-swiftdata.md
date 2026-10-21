# SwiftData 作为持久层

在 SwiftData、Core Data、GRDB 三者中选择 SwiftData:@Model 宏与 SwiftUI 原生集成让单表实体(见 CONTEXT.md「Daymark」)的样板代码最少。数据复杂度不足以摊销 Core Data 的样板成本或 GRDB 的手写 SQL。若未来遇到性能瓶颈,模型语义相近,可平迁 Core Data。
