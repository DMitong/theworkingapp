import { Milestone, MilestoneState, MilestoneVerificationType } from '../../types';
import { StateBadge } from '../common';

interface MilestoneTrackerProps {
  milestones: Milestone[];
  totalEscrowUsdc: bigint;
  /** Called when user signs a milestone (council member) */
  onSign?: (milestoneIndex: number) => void;
  /** Called when user votes on a milestone */
  onVote?: (milestoneIndex: number, approved: boolean) => void;
  /** Called when contractor submits evidence */
  onClaim?: (milestoneIndex: number) => void;
  canSign?: boolean;    // Is current user a council member?
  canClaim?: boolean;   // Is current user the awarded contractor?
  canVote?: boolean;    // Is current user a community member?
}

/**
 * MilestoneTracker
 *
 * Renders the full milestone schedule for a project with progress indicators,
 * payment amounts, verification type labels, and action buttons.
 *
 * BUILD GUIDE:
 * ─────────────────────────────────────────────────────────────
 * Layout (per milestone):
 *   [Connector line]
 *   [Index circle — coloured by state]
 *   [Milestone name + description]
 *   [Amount in USDC + percentage of total]
 *   [Verification type badge]
 *   [State badge]
 *   [Evidence link if submitted]
 *   [Action buttons — context-aware]
 *
 * Action button logic:
 *   PENDING:        No actions (waiting for contractor to claim)
 *   UNDER_REVIEW:
 *     - Contractor: "View evidence" only
 *     - Council (COUNCIL_ONLY type): "Sign milestone" button
 *     - Council (COUNCIL_MEMBER_QUORUM): "Sign" + signatures progress bar
 *     - Members (FULL_COMMUNITY_VOTE): "Approve / Reject" vote buttons
 *   PAID:           Show "Paid ✓" + date
 *   REJECTED:       Show "Rejected" + rejection count + resubmit CTA (contractor only)
 *
 * Signatures progress:
 *   For COUNCIL_ONLY and COUNCIL_MEMBER_QUORUM types, show:
 *   "2 of 3 council signatures collected"
 *   with a row of avatar circles (filled = signed, empty = pending)
 *
 * IPFS evidence:
 *   Link to gateway URL: ${PINATA_GATEWAY}/ipfs/${milestone.ipfsEvidence}
 *   Show thumbnail if it's an image, download link if PDF.
 *
 * Final milestone note:
 *   Always add a note: "Final milestone — subject to full community vote"
 *   regardless of the verificationType set.
 *
 * Amount formatting:
 *   USDC has 6 decimals. Display as: (value / 1_000_000).toLocaleString('en-US', { style: 'currency', currency: 'USD' })
 * ─────────────────────────────────────────────────────────────
 */
export default function MilestoneTracker({
  milestones,
  totalEscrowUsdc,
  onSign,
  onVote,
  onClaim,
  canSign = false,
  canClaim = false,
  canVote = false,
}: MilestoneTrackerProps) {
  const formatUsdc = (value: bigint) =>
    (Number(value) / 1_000_000).toLocaleString('en-US', { style: 'currency', currency: 'USD' });

  const pct = (value: bigint) =>
    totalEscrowUsdc === 0n ? 0 : Math.round((Number(value) * 100) / Number(totalEscrowUsdc));

  const verificationLabel: Record<MilestoneVerificationType, string> = {
    COUNCIL_ONLY: 'Council sign-off',
    COUNCIL_MEMBER_QUORUM: 'Council + member quorum',
    FULL_COMMUNITY_VOTE: 'Community vote',
  };

  const stateIcon: Record<MilestoneState, string> = {
    PENDING: '○',
    UNDER_REVIEW: '◎',
    PAID: '●',
    REJECTED: '✕',
  };

  return (
    <div className="space-y-0">
      {milestones.map((milestone, i) => {
        const isFinal = i === milestones.length - 1;
        const isUnderReview = milestone.state === MilestoneState.UNDER_REVIEW;

        return (
          <div key={milestone.index} className="flex gap-3">
            {/* Connector + index */}
            <div className="flex flex-col items-center">
              <div className={`w-8 h-8 rounded-full flex items-center justify-center font-bold text-sm flex-shrink-0 ${
                milestone.state === MilestoneState.PAID ? 'bg-teal text-white' :
                milestone.state === MilestoneState.UNDER_REVIEW ? 'bg-accent text-white' :
                milestone.state === MilestoneState.REJECTED ? 'bg-red-500 text-white' :
                'bg-slate/20 text-slate'
              }`}>
                {stateIcon[milestone.state]}
              </div>
              {i < milestones.length - 1 && (
                <div className={`w-0.5 flex-1 my-1 min-h-[24px] ${
                  milestone.state === MilestoneState.PAID ? 'bg-teal' : 'bg-slate/20'
                }`} />
              )}
            </div>

            {/* Content */}
            <div className="flex-1 pb-6">
              <div className="card space-y-2">
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <h4 className="font-semibold text-navy text-sm">{milestone.name}</h4>
                    <p className="text-xs text-slate mt-0.5">{milestone.description}</p>
                  </div>
                  <StateBadge state={milestone.state} />
                </div>

                <div className="flex items-center gap-2 flex-wrap">
                  <span className="font-bold text-teal">{formatUsdc(milestone.valueUsdc)}</span>
                  <span className="text-xs text-slate">({pct(milestone.valueUsdc)}% of total)</span>
                  <span className="badge-navy text-xs">{verificationLabel[milestone.verificationType]}</span>
                  {isFinal && <span className="badge-accent text-xs">Final milestone</span>}
                </div>

                {/* Signatures progress (council types) */}
                {isUnderReview && milestone.verificationType !== MilestoneVerificationType.FULL_COMMUNITY_VOTE && (
                  <p className="text-xs text-slate">
                    {milestone.signaturesReceived} of {milestone.signaturesRequired} signatures collected
                  </p>
                )}

                {/* Evidence link */}
                {milestone.ipfsEvidence && (
                  <a
                    href={`https://gateway.pinata.cloud/ipfs/${milestone.ipfsEvidence}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-xs text-teal underline"
                  >
                    View completion evidence →
                  </a>
                )}

                {/* Action buttons */}
                <div className="flex gap-2 pt-1 flex-wrap">
                  {canClaim && milestone.state === MilestoneState.PENDING && i === milestones.findIndex(m => m.state === MilestoneState.PENDING) && (
                    <button onClick={() => onClaim?.(milestone.index)} className="btn-primary text-sm px-4 py-2 min-h-[36px]">
                      Submit completion
                    </button>
                  )}
                  {canSign && isUnderReview && milestone.verificationType !== MilestoneVerificationType.FULL_COMMUNITY_VOTE && (
                    <button onClick={() => onSign?.(milestone.index)} className="btn-primary text-sm px-4 py-2 min-h-[36px]">
                      Sign milestone
                    </button>
                  )}
                  {canVote && isUnderReview && milestone.verificationType === MilestoneVerificationType.FULL_COMMUNITY_VOTE && (
                    <>
                      <button onClick={() => onVote?.(milestone.index, true)} className="btn-primary text-sm px-4 py-2 min-h-[36px]">
                        Approve
                      </button>
                      <button onClick={() => onVote?.(milestone.index, false)} className="btn-ghost text-sm px-4 py-2 min-h-[36px]">
                        Reject
                      </button>
                    </>
                  )}
                </div>
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}
