# 推送到 GitHub 操作向导

> 用途:把本地 `daymark` 仓库推到你的 GitHub 账号。每一步先打印要执行的操作,等你确认按回车再执行。最后一步把远端地址写回本地 git 配置。

## 需要你提供
- GitHub 用户名(下面用 `YOUR_USERNAME` 占位)
- 仓库名(默认 `daymark`)
- 可见性:public(开源,推荐)/ private

## 为什么装 gh
`git push` 需要 GitHub 认证。HTTPS + gh CLI 凭据助手是免 PAT 手工操作的标准做法;ssh key 也可以,但 gh 一步到位(装好后 `gh auth login` 一次,之后所有 push/pull 全自动)。

## 步骤 0:检查 gh 是否已装
[confirm] 检查 gh CLI:command -v gh || echo "未安装"

说明:如果输出"未安装",先走步骤 1 安装;否则跳到步骤 2。

## 步骤 1:安装 gh(brew)
[confirm] brew install gh

说明:约 1-2 分钟。装完运行 `gh --version` 验证。

## 步骤 2:登录 GitHub(浏览器交互,只有你能做)
[confirm] gh auth login --hostname github.com --git-protocol https

说明:交互式——选 "Login with a web browser",复制一次性代码到浏览器完成授权。这是只有你能完成的步骤。

## 步骤 3:填变量(替换后执行)
[confirm] read -r -p "GitHub 用户名: " GH_USER && read -r -p "仓库名 [daymark]: " REPO && REPO=\${REPO:-daymark}

## 步骤 4:创建远端仓库并推送
[confirm] gh repo create "\$GH_USER/\$REPO" --public --source . --remote origin --push

说明:一次完成"建仓 + 关联 origin + push"。想私有就换 `--private`。主分支当前叫 master,推送时可顺手改 main:`git branch -M main`(在上一条之前执行)。

## 步骤 5:验证
[confirm] git remote -v && git log --oneline -1 && gh repo view --json url -q .url

## 完成后
远端地址已写入 `.git/config`(origin)。以后每次提交后 `git push` 即可。README 和 LICENSE 文件属于 v1 收尾票,不阻塞推送。
