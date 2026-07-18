import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'TeleBridge',
  description: 'Telegram 双向沟通机器人 / Two-way Telegram Bridge Bot',
  lang: 'zh-CN',
  base: '/telegram-bridge/',

  head: [
    ['link', { rel: 'icon', href: '/telegram-bridge/favicon.ico' }],
  ],

  themeConfig: {
    logo: '/logo.svg',

    nav: [
      { text: '首页', link: '/' },
      { text: '指南', link: '/guide/introduction' },
      { text: '快速开始', link: '/guide/getting-started' },
      { text: '部署', link: '/guide/deployment/linux' },
      { text: '常见问题', link: '/guide/faq' },
      { text: '交流群组', link: 'https://t.me/kqxw_chat' },
    ],

    sidebar: {
      '/guide/': [
        {
          text: '入门',
          items: [
            { text: '简介', link: '/guide/introduction' },
            { text: '快速开始', link: '/guide/getting-started' },
            { text: '配置说明', link: '/guide/configuration' },
          ],
        },
        {
          text: '功能',
          items: [
            { text: '双向通讯', link: '/guide/features/two-way-messaging' },
            { text: '自动回复', link: '/guide/features/auto-reply' },
            { text: '广播消息', link: '/guide/features/broadcast' },
            { text: '内联按钮', link: '/guide/features/inline-buttons' },
            { text: '媒体转发', link: '/guide/features/media-forwarding' },
            { text: '设置面板', link: '/guide/features/settings-panel' },
          ],
        },
        {
          text: '部署',
          items: [
            { text: 'Linux 部署', link: '/guide/deployment/linux' },
            { text: 'Windows 部署', link: '/guide/deployment/windows' },
            { text: 'Docker 部署', link: '/guide/deployment/docker' },
          ],
        },
        {
          text: '其他',
          items: [
            { text: '管理员命令', link: '/guide/admin-commands' },
            { text: '常见问题', link: '/guide/faq' },
          ],
        },
      ],
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/aklibk86-dev/telegram-bridge' },
      { icon: 'telegram', link: 'https://t.me/kqxw_chat' },
    ],

    footer: {
      message: '基于 MIT 许可协议发布',
      copyright: 'Copyright 2024-present',
    },

    editLink: {
      pattern: 'https://github.com/aklibk86-dev/telegram-bridge/edit/main/docs/:path',
      text: '在 GitHub 上编辑此页',
    },

    lastUpdated: {
      text: '最后更新',
    },
  },
})
