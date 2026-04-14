import sgMail from '@sendgrid/mail';
import { env } from '../../config/env';
import { logger } from '../../utils/logger';

// Lazy-import io to avoid circular dependency
const getIO = () => {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  return require('../../index').io;
};

/**
 * NotificationService
 *
 * Handles sending multi-channel notifications:
 * 1. Email (via SendGrid)
 * 2. Real-time (via Socket.IO)
 * 3. In-app (stored in DB — TODO Phase 2)
 */
export class NotificationService {
  static init() {
    if (env.SENDGRID_API_KEY) {
      sgMail.setApiKey(env.SENDGRID_API_KEY);
      logger.info('NotificationService: SendGrid initialized');
    } else {
      logger.warn('NotificationService: SENDGRID_API_KEY not set, emails will be logged but not sent');
    }
  }

  /**
   * Send an email notification.
   */
  static async sendEmail(to: string, subject: string, text: string, html?: string) {
    const msg = {
      to,
      from: env.EMAIL_FROM,
      subject,
      text,
      html: html || text,
    };

    try {
      if (env.SENDGRID_API_KEY) {
        await sgMail.send(msg);
        logger.info(`Email sent to ${to}: ${subject}`);
      } else {
        logger.debug(`[MOCK EMAIL] To: ${to}, Subject: ${subject}`);
      }
    } catch (error) {
      logger.error('Failed to send email', { to, subject, error });
    }
  }

  /**
   * Send a real-time notification via Socket.IO.
   */
  static sendRealTime(room: string, event: string, data: any) {
    const io = getIO();
    if (io) {
      io.to(room).emit(event, data);
      logger.debug(`Socket event emitted: ${event} to room ${room}`);
    }
  }

  /**
   * Notify community of a new project proposal.
   */
  static async notifyNewProposal(communityId: string, projectId: string, title: string) {
    // 1. Real-time to community members
    this.sendRealTime(`community:${communityId}`, 'project:new-proposal', {
      projectId,
      title,
    });

    // 2. Email (In production, we'd fetch all member emails from the DB)
    // For v1, we log the intent.
    logger.info(`Notification: New proposal "${title}" in community ${communityId}`);
  }

  /**
   * Notify contractor of an awarded project.
   */
  static async notifyProjectAwarded(contractorEmail: string, projectId: string, title: string) {
    await this.sendEmail(
      contractorEmail,
      'Congratulations! Your proposal has been awarded',
      `Your proposal for "${title}" has been awarded by the community council. You can now begin work and fund the escrow.`
    );

    this.sendRealTime(`project:${projectId}`, 'project:awarded', { projectId, title });
  }

  /**
   * Notify signatories of a new milestone claim.
   */
  static async notifyMilestoneClaim(projectId: string, index: number, title: string) {
    this.sendRealTime(`project:${projectId}`, 'project:milestone-claim', {
      projectId,
      index,
      title,
    });
    
    // In production, fetch council emails and send alerts
    logger.info(`Notification: Milestone ${index} claim submitted for project ${title}`);
  }

  /**
   * Notify contractor of a paid milestone.
   */
  static async notifyMilestonePaid(contractorEmail: string, projectId: string, index: number, amount: string) {
    await this.sendEmail(
      contractorEmail,
      'Milestone Payment Released',
      `Milestone ${index} for project ${projectId} has been approved and ${amount} USDC has been released to your wallet.`
    );
  }
}
