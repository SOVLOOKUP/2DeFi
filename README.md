# 2DeFi

- 利用闲置存储和带宽资源分享文件，获得分享奖励
- 通过贡献可靠存储空间获得存储奖励
- 存储和分享的文件和数据具有确定性所有权/版权/隐私
- 通过内置应用打开分享文件，自带负载均衡，具有缓存策略，支持音视频、图片、文本、静态Web等主流文件类型
- 存储贡献和分享文件记录在区块链上，实现数据确权、流转、可溯源
  

# 现在的功能:

- 为了能最快的让DHT正常工作，p2pd.exe已经提前编译好, 并打开了Gossip pub/sub功能，如果担心安全问题，你仍然可以自己编译[go-libp2p-daemon](https://github.com/libp2p/go-libp2p-daemon)

1. 连接节点开始点对点聊天:

- `/connect QmQx4FvYELrxrB7cPtwowpZbRAmNytitVPZCT6dGaJZScj`

2. 搜索公网节点，可以穿透内网，接入公网:

- `/search 12D3KooWFu9cU6GTbti1Xcqj9Z32dcpk5xwNzTriYYZzjKLTDAme`

3. 发布和订阅。打开文件会在节点昵称频道下发布提示信息，订阅用户收到分享的文件超链接（实现中）：

- `/sub 新闻`
- `/pub 新闻 "今日热点"`


# TODO:

- [X] 节点昵称
- [X] Gossip协议的发布/订阅
- [X] 文件分享发布
- [ ] 文件超链接使用系统默认应用打开
- [ ] 存储贡献和分享的文件信息存储在区块链上
- [ ] 文件超链接使用内置应用打开
- [ ] 文件所有权/版权/隐私算法
- [ ] Liunx/MacOS/手机端跨平台

