# xToriMicz — Org Knowledge

ไฟล์นี้เป็นความรู้กลางขององค์กร Oracle ทุกตัวควรอ่านเมื่อเริ่ม session

## Team Oracle (12 ตัว)

| Oracle | หน้าที่ | Repo |
|--------|---------|------|
| Jingjing (จิงจิง) | Frontend/UI/UX, Web Automation | Jingjing-oracle |
| Sila (ศีล) | Backend/API/Database | Sila-oracle |
| Panya (ปัญญา) | Data/Research/Analytics | Panya-oracle |
| Wiriya (วิริยะ) | DevOps/Infra/Deploy | Wiriya-oracle |
| Sati (สติ) | QA/Testing | Sati-oracle |
| Thaan (ทาน) | Content/Social/Blog | Thaan-oracle |
| Metta (เมตตา) | Community/UX Research | Metta-oracle |
| Khanti (ขันติ) | Debug/Troubleshoot | Khanti-oracle |
| Sajja (สัจจะ) | Security/Audit | Sajja-oracle |
| Athitthaan (อธิษฐาน) | Project Management | Athitthaan-oracle |
| Ubekkha (อุเบกขา) | Monitoring/Observability | Ubekkha-oracle |
| Kumo (คุโมะ) | Graphic Design/Branding | kumo-oracle |

## Websites & Repos

| เว็บ | URL | หมายเหตุ |
|------|-----|----------|
| Parami Oracle Team | https://parami.makeloops.xyz/ | หน้าแนะนำทีม Oracle — ห้าม deploy ทับ |

## Infrastructure

- **Task Management**: `pulse` CLI → GitHub Projects V2
- **Agent Control**: `maw` CLI → tmux sessions
- **Web UI**: http://localhost:3456 (maw serve)
- **Sentry**: ทุก 15 นาที post to Discussion #2
- **GitHub Org**: xToriMicz
- **Main Board**: Project #1 "Jingjing Board"
- **Discussion Repo**: Gabbzaa-Agents

## การส่งงานต่อ

- ใช้ `pulse add "title"` → routing จ่ายอัตโนมัติ
- ถ้ารู้ว่าต้องส่งใคร → `pulse add "title" --oracle <name>`
- ถ้าต้องการถามก่อน → `/talk-to <oracle> "question"`
- **ห้าม close issue ถ้างานยังไม่ถึงปลายทางจริง**

## กฎสำคัญ

1. ตรวจสอบสถานะปัจจุบันก่อนแก้ไขเสมอ (fetch เว็บ, ดู git log)
2. ถ้าทำเองไม่จบ ต้องส่งต่อ ห้ามทิ้งงาน
3. คุยกับทีมผ่าน `/talk-to` — อย่าทำคนเดียวถ้าไม่แน่ใจ
4. ห้าม deploy ทับของเดิมโดยไม่ตรวจสอบก่อน
