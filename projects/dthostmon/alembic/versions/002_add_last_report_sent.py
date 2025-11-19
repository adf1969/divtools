"""
Database migration: Add last_report_sent column to hosts table
Last Updated: 1/16/2025 12:45:00 PM CST

Migration for Session 10 reporting enhancements (FR-ANALYSIS-006)
Adds last_report_sent timestamp to track when reports were last sent for frequency-based scheduling.
"""

from alembic import op
import sqlalchemy as sa


# Revision identifiers
revision = '002_add_last_report_sent'
down_revision = '001_add_site_and_report_frequency'
branch_labels = None
depends_on = None


def upgrade():
    """
    Add last_report_sent column to hosts table
    
    - last_report_sent: TIMESTAMP - Timestamp of when the last report was sent
    
    This column is nullable to maintain backward compatibility. NULL indicates no report has been sent yet.
    """
    # Add last_report_sent column for tracking report scheduling
    op.add_column('hosts', sa.Column('last_report_sent', sa.DateTime(), nullable=True))
    
    print("✅ Migration complete: Added last_report_sent column to hosts table")
    print("ℹ️  Existing hosts will have NULL values - reports will be sent on next monitoring run")


def downgrade():
    """
    Remove last_report_sent column from hosts table
    
    WARNING: This will delete all report scheduling history!
    """
    # Drop column
    op.drop_column('hosts', 'last_report_sent')
    
    print("⚠️  Migration rolled back: Removed last_report_sent column from hosts table")
