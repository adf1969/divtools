"""
Database migration: Add site and report_frequency columns to hosts table
Last Updated: 11/15/2025 4:15:00 PM CST

Migration for Session 10 reporting enhancements (FR-CONFIG-006)
Adds site identifier and report frequency override fields to hosts table.
"""

from alembic import op
import sqlalchemy as sa


# Revision identifiers
revision = '001_add_site_and_report_frequency'
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    """
    Add site and report_frequency columns to hosts table
    
    - site: VARCHAR(100) - Site identifier for grouping (e.g., "s01-chicago")
    - report_frequency: VARCHAR(50) - Report frequency override (e.g., "daily", "weekly", "hourly")
    
    Both columns are nullable to maintain backward compatibility with existing hosts.
    """
    # Add site column with index for efficient site-based queries
    op.add_column('hosts', sa.Column('site', sa.String(100), nullable=True))
    op.create_index('ix_hosts_site', 'hosts', ['site'])
    
    # Add report_frequency column for hierarchical frequency configuration
    op.add_column('hosts', sa.Column('report_frequency', sa.String(50), nullable=True))
    
    print("✅ Migration complete: Added site and report_frequency columns to hosts table")
    print("ℹ️  Existing hosts will have NULL values - update via API or config reload")


def downgrade():
    """
    Remove site and report_frequency columns from hosts table
    
    WARNING: This will delete all site and report_frequency data!
    """
    # Drop index first
    op.drop_index('ix_hosts_site', 'hosts')
    
    # Drop columns
    op.drop_column('hosts', 'report_frequency')
    op.drop_column('hosts', 'site')
    
    print("⚠️  Migration rollback complete: Removed site and report_frequency columns")
    print("⚠️  All site and report frequency configuration data has been deleted")
