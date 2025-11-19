"""
Logging utilities for dthostmon
Last Updated: 11/14/2025 12:00:00 PM CDT

Structured logging setup with color output and JSON formatting options.
"""

import logging
import sys
from datetime import datetime
from typing import Optional


# ANSI color codes for terminal output
class LogColors:
    DEBUG = '\033[37m'    # White
    INFO = '\033[36m'     # Cyan
    WARN = '\033[33m'     # Yellow
    ERROR = '\033[31m'    # Red
    CRITICAL = '\033[35m' # Magenta
    RESET = '\033[0m'     # Reset


class ColoredFormatter(logging.Formatter):
    """Custom formatter with color support"""
    
    COLORS = {
        'DEBUG': LogColors.DEBUG,
        'INFO': LogColors.INFO,
        'WARNING': LogColors.WARN,
        'ERROR': LogColors.ERROR,
        'CRITICAL': LogColors.CRITICAL,
    }
    
    def format(self, record):
        # Add color to level name
        levelname = record.levelname
        if levelname in self.COLORS:
            record.levelname = f"{self.COLORS[levelname]}{levelname}{LogColors.RESET}"
        
        # Format the message
        result = super().format(record)
        
        # Reset levelname for next use
        record.levelname = levelname
        
        return result


def setup_logging(level: str = "INFO", log_file: Optional[str] = None, json_format: bool = False):
    """
    Setup application logging
    
    Args:
        level: Logging level (DEBUG, INFO, WARN, ERROR, CRITICAL)
        log_file: Optional log file path
        json_format: Use JSON formatting (useful for log aggregation)
    """
    # Convert level string to logging constant
    numeric_level = getattr(logging, level.upper(), logging.INFO)
    
    # Create root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(numeric_level)
    
    # Remove existing handlers
    root_logger.handlers = []
    
    # Console handler with colors
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(numeric_level)
    
    if json_format:
        # JSON format for log aggregation
        console_format = '{"time":"%(asctime)s","level":"%(levelname)s","name":"%(name)s","message":"%(message)s"}'
        console_formatter = logging.Formatter(console_format)
    else:
        # Human-readable format with colors
        console_format = '%(asctime)s [%(levelname)s] %(name)s: %(message)s'
        console_formatter = ColoredFormatter(
            console_format,
            datefmt='%Y-%m-%d %H:%M:%S'
        )
    
    console_handler.setFormatter(console_formatter)
    root_logger.addHandler(console_handler)
    
    # File handler (if specified)
    if log_file:
        file_handler = logging.FileHandler(log_file)
        file_handler.setLevel(numeric_level)
        
        if json_format:
            file_formatter = logging.Formatter(console_format)
        else:
            file_format = '%(asctime)s [%(levelname)s] %(name)s: %(message)s'
            file_formatter = logging.Formatter(file_format, datefmt='%Y-%m-%d %H:%M:%S')
        
        file_handler.setFormatter(file_formatter)
        root_logger.addHandler(file_handler)
    
    logging.info(f"Logging initialized at {level} level")
