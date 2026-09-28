import type { SVGProps } from 'react'

type IconProps = SVGProps<SVGSVGElement> & { size?: number }

function base({ size = 20, ...rest }: IconProps) {
  return {
    width: size,
    height: size,
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth: 1.8,
    strokeLinecap: 'round' as const,
    strokeLinejoin: 'round' as const,
    'aria-hidden': true,
    ...rest,
  }
}

export const IconOverview = (p: IconProps) => (
  <svg {...base(p)}><rect x="3" y="3" width="7" height="9" rx="1.5" /><rect x="14" y="3" width="7" height="5" rx="1.5" /><rect x="14" y="12" width="7" height="9" rx="1.5" /><rect x="3" y="16" width="7" height="5" rx="1.5" /></svg>
)
export const IconFunnel = (p: IconProps) => (
  <svg {...base(p)}><path d="M3 4h18l-7 8.5V19l-4 2v-8.5L3 4z" /></svg>
)
export const IconMembers = (p: IconProps) => (
  <svg {...base(p)}><circle cx="9" cy="8" r="3.5" /><path d="M2.5 20c0-3.6 2.9-6 6.5-6s6.5 2.4 6.5 6" /><circle cx="17.5" cy="9" r="2.5" /><path d="M16.5 14.2c2.7.3 5 2.2 5 5.3" /></svg>
)
export const IconTasks = (p: IconProps) => (
  <svg {...base(p)}><rect x="4" y="3.5" width="16" height="17" rx="2.5" /><path d="M8.5 9.5l1.8 1.8 3.4-3.4" /><path d="M8.5 15.5h7" /></svg>
)
export const IconChat = (p: IconProps) => (
  <svg {...base(p)}><path d="M4 5h16v11H9l-5 4V5z" /></svg>
)
export const IconChart = (p: IconProps) => (
  <svg {...base(p)}><path d="M4 20V10" /><path d="M10 20V4" /><path d="M16 20v-7" /><path d="M22 20H2" /></svg>
)
export const IconSettings = (p: IconProps) => (
  <svg {...base(p)}><circle cx="12" cy="12" r="3" /><path d="M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3M5.3 5.3l2.1 2.1M16.6 16.6l2.1 2.1M5.3 18.7l2.1-2.1M16.6 7.4l2.1-2.1" /></svg>
)
export const IconSearch = (p: IconProps) => (
  <svg {...base(p)}><circle cx="11" cy="11" r="7" /><path d="M20 20l-3.5-3.5" /></svg>
)
export const IconDownload = (p: IconProps) => (
  <svg {...base(p)}><path d="M12 4v11" /><path d="M7 10l5 5 5-5" /><path d="M5 20h14" /></svg>
)
export const IconHistory = (p: IconProps) => (
  <svg {...base(p)}><path d="M3 12a9 9 0 103-6.7L3 8" /><path d="M3 3v5h5" /><path d="M12 7v5l3 2" /></svg>
)
export const IconClose = (p: IconProps) => (
  <svg {...base({ strokeWidth: 2.2, ...p })}><path d="M6 6l12 12M18 6L6 18" /></svg>
)
export const IconPlus = (p: IconProps) => (
  <svg {...base({ strokeWidth: 2, ...p })}><path d="M12 5v14M5 12h14" /></svg>
)
export const IconChevronDown = (p: IconProps) => (
  <svg {...base({ strokeWidth: 2, ...p })}><path d="M6 9l6 6 6-6" /></svg>
)
export const IconArrowRight = (p: IconProps) => (
  <svg {...base({ strokeWidth: 2, ...p })}><path d="M5 12h14" /><path d="M13 6l6 6-6 6" /></svg>
)
export const IconImage = (p: IconProps) => (
  <svg {...base(p)}><rect x="3" y="4" width="18" height="16" rx="2.5" /><circle cx="9" cy="10" r="2" /><path d="M21 16l-5-5-8 9" /></svg>
)
export const IconCalendar = (p: IconProps) => (
  <svg {...base({ strokeWidth: 2, ...p })}><rect x="3" y="5" width="18" height="16" rx="2" /><path d="M3 10h18M8 3v4M16 3v4" /></svg>
)
export const IconFlag = (p: IconProps) => (
  <svg {...base({ strokeWidth: 2, ...p })}><path d="M5 21V4h11l-2 4 2 4H5" /></svg>
)
export const IconMail = (p: IconProps) => (
  <svg {...base({ strokeWidth: 2, ...p })}><rect x="3" y="5" width="18" height="14" rx="2" /><path d="M3 7l9 6 9-6" /></svg>
)
export const IconNote = (p: IconProps) => (
  <svg {...base({ strokeWidth: 2, ...p })}><path d="M5 4h10l4 4v12H5z" /><path d="M9 12h6M9 16h4" /></svg>
)
export const IconLogout = (p: IconProps) => (
  <svg {...base(p)}><path d="M15 4h4v16h-4" /><path d="M10 8l-4 4 4 4" /><path d="M6 12h10" /></svg>
)

/** The assistant's avatar (original illustration). */
export function AssistantAvatar({ size = 32 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 40 40" aria-hidden="true" style={{ flexShrink: 0, display: 'block' }}>
      <circle cx="20" cy="20" r="20" fill="#E9E6FC" />
      <path d="M9 38c1.5-7 6-10.5 11-10.5S29.5 31 31 38" fill="#5B4BDB" />
      <circle cx="20" cy="17.5" r="7" fill="#F2C9A5" />
      <path d="M12.6 17.2c-.4-6 3.3-9.4 7.6-9.4 4.6 0 8.1 3.4 7.2 9.6-1.1-3.1-3.3-4.9-7.1-5.3-2.6 2.2-5.1 3.6-7.7 5.1z" fill="#2B2340" />
      <circle cx="17.3" cy="18.3" r="0.9" fill="#2B2340" />
      <circle cx="22.7" cy="18.3" r="0.9" fill="#2B2340" />
      <path d="M17.6 21.3c1.4 1.1 3.4 1.1 4.8 0" stroke="#B5645A" strokeWidth="1.1" fill="none" strokeLinecap="round" />
    </svg>
  )
}
