import { Outlet, NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';

const navItems = [
  { to: '/dashboard', label: 'Home',      icon: '⊞' },
  { to: '/discover',  label: 'Discover',  icon: '⊕' },
  { to: '/bounties',  label: 'Bounties',  icon: '◈' },
];

/**
 * AppShell — Mobile-first layout with bottom navigation bar.
 *
 * BUILD GUIDE:
 * ─────────────────────────────────────────────────────────────
 * Layout structure:
 *   <header>  — fixed top bar: The Working App logo + right-side profile avatar
 *   <main>    — scrollable content area with bottom padding (for nav bar)
 *   <nav>     — fixed bottom navigation (mobile-first)
 *
 * Desktop (md breakpoint):
 *   Switch to a left sidebar navigation instead of bottom nav.
 *   <aside> with expanded nav labels.
 *   <main> takes the remaining horizontal space.
 *
 * Icons:
 *   Replace unicode placeholders with proper SVG icons.
 *   Recommended: Heroicons (heroicons.dev) or Phosphor Icons.
 *   Install: npm install @heroicons/react
 *
 * Notifications badge:
 *   Add a red dot badge on the profile icon when there are unread notifications.
 *   Fetch count from /api/v1/users/me/notifications/count on mount.
 *   Listen for Socket.IO 'notification' events to update count in real time.
 *
 * Mode indicator:
 *   Show a subtle "⛓ On-chain" badge in the header when user is in Crypto-Native mode.
 *   Hidden in Standard Mode.
 * ─────────────────────────────────────────────────────────────
 */
export default function AppShell() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  return (
    <div className="flex flex-col min-h-screen">
      {/* Top bar */}
      <header className="fixed top-0 left-0 right-0 z-40 bg-white border-b border-slate/10 px-4 h-14 flex items-center justify-between shadow-sm">
        <span className="font-bold text-navy text-lg tracking-tight">The Working App</span>
        <button
          onClick={() => navigate(`/profile/${user?.handle}`)}
          className="w-9 h-9 rounded-full bg-teal text-white font-bold text-sm flex items-center justify-center"
        >
          {user?.handle?.[0]?.toUpperCase() ?? '?'}
        </button>
      </header>

      {/* Page content */}
      <main className="flex-1 pt-14 pb-20 px-4 max-w-2xl mx-auto w-full">
        <Outlet />
      </main>

      {/* Bottom navigation */}
      <nav className="fixed bottom-0 left-0 right-0 z-40 bg-white border-t border-slate/10 flex justify-around items-center h-16 px-2">
        {navItems.map(({ to, label, icon }) => (
          <NavLink
            key={to}
            to={to}
            className={({ isActive }) =>
              `flex flex-col items-center gap-0.5 px-5 py-1 rounded-lg transition-colors min-w-[64px] ${
                isActive ? 'text-teal' : 'text-slate'
              }`
            }
          >
            <span className="text-xl">{icon}</span>
            <span className="text-[10px] font-medium">{label}</span>
          </NavLink>
        ))}
        <button
          onClick={() => navigate('/settings')}
          className="flex flex-col items-center gap-0.5 px-5 py-1 rounded-lg text-slate min-w-[64px]"
        >
          <span className="text-xl">⚙</span>
          <span className="text-[10px] font-medium">Settings</span>
        </button>
      </nav>
    </div>
  );
}
