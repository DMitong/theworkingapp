import { Routes, Route, Navigate } from 'react-router-dom';
import { useAuth } from './context/AuthContext';

// Layouts
import AppShell from './components/common/AppShell';

// Pages
import LoginPage from './pages/LoginPage';
import RegisterPage from './pages/RegisterPage';
import DashboardPage from './pages/DashboardPage';
import DiscoverPage from './pages/DiscoverPage';
import CommunityPage from './pages/CommunityPage';
import ProjectDetailPage from './pages/ProjectDetailPage';
import NewProjectPage from './pages/NewProjectPage';
import BountyListPage from './pages/BountyListPage';
import BountyDetailPage from './pages/BountyDetailPage';
import NewBountyPage from './pages/NewBountyPage';
import ProfilePage from './pages/ProfilePage';
import SettingsPage from './pages/SettingsPage';
import NewCommunityPage from './pages/NewCommunityPage';
import MediationPage from './pages/MediationPage';

function PrivateRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, isLoading } = useAuth();
  if (isLoading) return <div className="flex items-center justify-center min-h-screen"><span className="text-slate">Loading…</span></div>;
  return isAuthenticated ? <>{children}</> : <Navigate to="/login" replace />;
}

export default function App() {
  return (
    <Routes>
      {/* Public */}
      <Route path="/login" element={<LoginPage />} />
      <Route path="/register" element={<RegisterPage />} />

      {/* Private — wrapped in AppShell (nav + layout) */}
      <Route path="/" element={<PrivateRoute><AppShell /></PrivateRoute>}>
        <Route index element={<Navigate to="/dashboard" replace />} />
        <Route path="dashboard" element={<DashboardPage />} />
        <Route path="discover" element={<DiscoverPage />} />

        {/* Communities */}
        <Route path="communities/new" element={<NewCommunityPage />} />
        <Route path="communities/:communityId" element={<CommunityPage />} />
        <Route path="communities/:communityId/projects/new" element={<NewProjectPage />} />

        {/* Projects */}
        <Route path="projects/:projectId" element={<ProjectDetailPage />} />

        {/* Bounties */}
        <Route path="bounties" element={<BountyListPage />} />
        <Route path="bounties/new" element={<NewBountyPage />} />
        <Route path="bounties/:bountyId" element={<BountyDetailPage />} />

        {/* User */}
        <Route path="profile/:handle" element={<ProfilePage />} />
        <Route path="settings" element={<SettingsPage />} />

        {/* Platform admin */}
        <Route path="mediation/:disputeId" element={<MediationPage />} />
      </Route>

      <Route path="*" element={<Navigate to="/dashboard" replace />} />
    </Routes>
  );
}
