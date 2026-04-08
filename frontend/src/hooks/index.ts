/**
 * Frontend Custom Hooks
 *
 * All data-fetching hooks use React Query (@tanstack/react-query).
 * Pattern: useQuery wraps api.get(), useMutation wraps api.post/put/patch.
 *
 * BUILD GUIDE:
 * ─────────────────────────────────────────────────────────────
 * Implement each hook below. They are already imported by pages/components
 * that reference them — implement them to make those components work.
 *
 * Naming convention:
 *   useXxx()         → read (useQuery)
 *   useXxxMutation() → write (useMutation)
 *
 * Error handling:
 *   React Query surfaces errors via isError + error.
 *   Global error toasts should be wired in App.tsx via QueryClient's
 *   onError callback, not inside each hook.
 *
 * Optimistic updates:
 *   For vote actions (proposal vote, milestone vote, completion vote),
 *   use onMutate to optimistically update the cache before the server responds.
 *   Revert on onError. This makes voting feel instant.
 *
 * Socket.IO integration:
 *   Hooks that show real-time data (vote counts, project state) should
 *   also subscribe to Socket.IO events and update the React Query cache
 *   via queryClient.setQueryData() when events arrive.
 *   See useProjectDetail for the pattern.
 * ─────────────────────────────────────────────────────────────
 */

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import api from '../lib/api';
import { useSocket } from '../context/SocketContext';
import { useEffect } from 'react';

// ── Auth ──────────────────────────────────────────────────────

export function useMe() {
  return useQuery({
    queryKey: ['me'],
    queryFn: () => api.get('/users/me').then(r => r.data.data),
    staleTime: 60_000,
  });
}

// ── Communities ───────────────────────────────────────────────

export function useCommunity(communityId: string) {
  return useQuery({
    queryKey: ['community', communityId],
    queryFn: () => api.get(`/communities/${communityId}`).then(r => r.data.data),
    enabled: !!communityId,
  });
}

export function useCommunityProjects(communityId: string, state?: string) {
  return useQuery({
    queryKey: ['community-projects', communityId, state],
    queryFn: () => api.get(`/communities/${communityId}/projects`, { params: { state } }).then(r => r.data.data),
    enabled: !!communityId,
  });
}

export function useSearchCommunities(query: string) {
  return useQuery({
    queryKey: ['communities-search', query],
    queryFn: () => api.get('/communities/search', { params: { q: query } }).then(r => r.data.data),
    enabled: query.length >= 2,
    staleTime: 10_000,
  });
}

export function useCreateCommunityMutation() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (data: Record<string, unknown>) => api.post('/communities', data).then(r => r.data.data),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['me'] }),
  });
}

export function useApplyMembershipMutation(communityId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (proofData: Record<string, unknown>) =>
      api.post(`/communities/${communityId}/membership/apply`, proofData).then(r => r.data.data),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['community', communityId] }),
  });
}

// ── Projects ──────────────────────────────────────────────────

/**
 * useProjectDetail — fetches project + subscribes to real-time updates.
 *
 * BUILD:
 *   1. Fetch project from GET /api/v1/projects/:projectId
 *   2. On mount, join Socket.IO room `project:${projectId}`
 *   3. Listen for 'project:state', 'project:votes', 'project:milestone-paid'
 *   4. On each event, update the React Query cache:
 *      queryClient.setQueryData(['project', projectId], updater)
 *   5. On unmount, leave the room
 */
export function useProjectDetail(projectId: string) {
  const qc = useQueryClient();
  const { socket, joinRoom, leaveRoom } = useSocket();

  const query = useQuery({
    queryKey: ['project', projectId],
    queryFn: () => api.get(`/projects/${projectId}`).then(r => r.data.data),
    enabled: !!projectId,
  });

  useEffect(() => {
    if (!projectId) return;
    joinRoom(projectId);

    const handleStateChange = (data: { state: number }) => {
      // TODO: Map numeric state to ProjectState enum string
      qc.invalidateQueries({ queryKey: ['project', projectId] });
    };

    const handleVoteUpdate = (data: { upvotes: number; downvotes: number }) => {
      qc.setQueryData(['project', projectId], (old: any) =>
        old ? { ...old, upvoteCount: data.upvotes, downvoteCount: data.downvotes } : old,
      );
    };

    socket?.on('project:state', handleStateChange);
    socket?.on('project:votes', handleVoteUpdate);

    return () => {
      leaveRoom(projectId);
      socket?.off('project:state', handleStateChange);
      socket?.off('project:votes', handleVoteUpdate);
    };
  }, [projectId, socket, joinRoom, leaveRoom, qc]);

  return query;
}

export function useCastProposalVoteMutation(projectId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (upvote: boolean) =>
      api.post(`/projects/${projectId}/vote/proposal`, { upvote }).then(r => r.data.data),
    // Optimistic update
    onMutate: async (upvote) => {
      await qc.cancelQueries({ queryKey: ['project', projectId] });
      const prev = qc.getQueryData(['project', projectId]);
      qc.setQueryData(['project', projectId], (old: any) =>
        old
          ? {
              ...old,
              upvoteCount: old.upvoteCount + (upvote ? 1 : 0),
              downvoteCount: old.downvoteCount + (!upvote ? 1 : 0),
            }
          : old,
      );
      return { prev };
    },
    onError: (_err, _vars, ctx) => {
      if (ctx?.prev) qc.setQueryData(['project', projectId], ctx.prev);
    },
    onSettled: () => qc.invalidateQueries({ queryKey: ['project', projectId] }),
  });
}

export function useCastCompletionVoteMutation(projectId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (choice: string) =>
      api.post(`/projects/${projectId}/vote/completion`, { choice }).then(r => r.data.data),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['project', projectId] }),
  });
}

export function useSignMilestoneMutation(projectId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (milestoneIndex: number) =>
      api.post(`/projects/${projectId}/milestones/${milestoneIndex}/sign`, {}).then(r => r.data.data),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['project', projectId] }),
  });
}

export function useSubmitMilestoneClaimMutation(projectId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ milestoneIndex, formData }: { milestoneIndex: number; formData: FormData }) =>
      api.post(`/projects/${projectId}/milestones/${milestoneIndex}/claim`, formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      }).then(r => r.data.data),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['project', projectId] }),
  });
}

// ── Bounties ──────────────────────────────────────────────────

export function useBounties(filters?: Record<string, string>) {
  return useQuery({
    queryKey: ['bounties', filters],
    queryFn: () => api.get('/bounties', { params: filters }).then(r => r.data.data),
  });
}

export function useBountyDetail(bountyId: string) {
  return useQuery({
    queryKey: ['bounty', bountyId],
    queryFn: () => api.get(`/bounties/${bountyId}`).then(r => r.data.data),
    enabled: !!bountyId,
  });
}

// ── Escrow ────────────────────────────────────────────────────

export function useInitiateEscrowFunding() {
  return useMutation({
    mutationFn: (data: { contractAddress: string; amountUsd: number; token: 'USDT' | 'USDC'; projectId: string }) =>
      api.post('/escrow/fund/initiate', data).then(r => r.data.data),
  });
}
