#!/usr/bin/env python3
"""Setup script for dtpyutil - Divtools Python Utilities

This enables editable installation:
    cd $DIVTOOLS/scripts/venvs/dtpyutil
    ./bin/pip install -e $DIVTOOLS/projects/dtpyutil

After editable install, you can import from any project:
    from dtpyutil.menu import DtpMenuApp
    from dtpyutil.logging import setup_logger

With editable install, changes to dtpyutil source code take effect immediately
without reinstalling - perfect for active development.
"""

from setuptools import setup, find_packages
from pathlib import Path

# Read README for long description
readme_file = Path(__file__).parent / "README.md"
long_description = readme_file.read_text() if readme_file.exists() else ""

setup(
    name="dtpyutil",
    version="1.0.0",
    description="Divtools Python Utilities - Shared libraries and tools",
    long_description=long_description,
    long_description_content_type="text/markdown",
    author="Divtools Project",
    url="https://github.com/yourusername/divtools",
    
    # Package discovery
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    
    # Dependencies (installed in venv)
    install_requires=[
        "textual>=0.47.0",  # TUI framework for menu system
    ],
    
    # Optional dependencies for development
    extras_require={
        "dev": [
            "pytest>=7.0.0",
            "pytest-cov>=4.0.0",
        ],
    },
    
    # Python version requirement
    python_requires=">=3.10",
    
    # Package metadata
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
    ],
    
    # Entry points (optional - for future CLI tools)
    entry_points={
        "console_scripts": [
            # Future: "dtpmenu=dtpyutil.menu.dtpmenu:main",
        ],
    },
)
