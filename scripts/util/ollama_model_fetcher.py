#!/usr/bin/env python3
# Ollama Model Information Fetcher and Downloader
# Last Updated: 11/7/2025 5:00:00 PM CST
#
# This script fetches current model information from ollama.com library
# and allows interactive selection for downloading models.
#
# Usage:
#   ./ollama_model_fetcher.py [--config models.txt] [--download] [--format table|json]
#
# Requirements:
#   pip install requests beautifulsoup4 rich

import argparse
import json
import re
import sys
from typing import Dict, List, Optional
from pathlib import Path

try:
    import requests
    from bs4 import BeautifulSoup
    from rich.console import Console
    from rich.table import Table
    from rich.prompt import Prompt, Confirm
    from rich.progress import Progress
except ImportError:
    print("ERROR: Required packages not installed.")
    print("Install with: pip install requests beautifulsoup4 rich")
    sys.exit(1)

console = Console()


class OllamaModelFetcher:
    """Fetches and manages Ollama model information."""
    
    def __init__(self):
        self.base_url = "https://ollama.com"
        self.api_url = f"{self.base_url}/api/tags"
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'
        })
    
    def fetch_model_list(self) -> List[Dict]:
        """Fetch list of all available models from Ollama API."""
        try:
            response = self.session.get(self.api_url, timeout=10)
            response.raise_for_status()
            data = response.json()
            return data.get('models', [])
        except Exception as e:
            console.print(f"[red]Error fetching model list: {e}[/red]")
            return []
    
    def fetch_model_details(self, model_name: str) -> Optional[Dict]:
        """Fetch detailed information for a specific model from the library page."""
        url = f"{self.base_url}/library/{model_name}"
        
        try:
            response = self.session.get(url, timeout=10)
            response.raise_for_status()
            soup = BeautifulSoup(response.text, 'html.parser')
            
            # Extract model information
            details = {
                'name': model_name,
                'url': url,
                'variants': [],
                'description': '',
                'capabilities': [],
                'context_window': 'Unknown'
            }
            
            # Try to find description
            desc_elem = soup.find('meta', {'property': 'og:description'})
            if desc_elem:
                details['description'] = desc_elem.get('content', '').strip()
            
            # Look for context window information in the page text
            page_text = soup.get_text()
            context_matches = re.findall(r'(\d+)K\s*(?:tokens?|context)', page_text, re.IGNORECASE)
            if context_matches:
                # Get the largest context window mentioned
                max_context = max([int(x) for x in context_matches])
                details['context_window'] = f"{max_context}K tokens"
            
            # Find model variants table
            tables = soup.find_all('table')
            for table in tables:
                rows = table.find_all('tr')
                for row in rows[1:]:  # Skip header
                    cols = row.find_all('td')
                    if len(cols) >= 3:
                        variant_name = cols[0].get_text().strip()
                        size = cols[1].get_text().strip()
                        context = cols[2].get_text().strip()
                        input_type = cols[3].get_text().strip() if len(cols) > 3 else 'Text'
                        
                        details['variants'].append({
                            'name': variant_name,
                            'size': size,
                            'context': context,
                            'input_type': input_type
                        })
            
            # Check for capabilities (vision, tools, etc.)
            if 'vision' in page_text.lower() or 'image' in page_text.lower():
                details['capabilities'].append('Vision')
            if 'tool' in page_text.lower() or 'function calling' in page_text.lower():
                details['capabilities'].append('Tools')
            if 'code' in model_name.lower():
                details['capabilities'].append('Code')
            
            return details
            
        except Exception as e:
            console.print(f"[yellow]Warning: Could not fetch details for {model_name}: {e}[/yellow]")
            return None
    
    def search_models(self, model_names: List[str]) -> List[Dict]:
        """Search for specific models and return their details."""
        results = []
        
        with Progress() as progress:
            task = progress.add_task("[cyan]Fetching model information...", total=len(model_names))
            
            for model_name in model_names:
                # Clean model name (remove version tags if present)
                base_name = model_name.split(':')[0]
                
                details = self.fetch_model_details(base_name)
                if details:
                    results.append(details)
                
                progress.update(task, advance=1)
        
        return results


def load_models_from_file(filepath: str) -> List[str]:
    """Load model names from a file (one per line)."""
    try:
        path = Path(filepath)
        if not path.exists():
            console.print(f"[red]File not found: {filepath}[/red]")
            return []
        
        with open(path, 'r') as f:
            models = [line.strip() for line in f if line.strip() and not line.startswith('#')]
        
        return models
    except Exception as e:
        console.print(f"[red]Error reading file: {e}[/red]")
        return []


def save_models_to_file(filepath: str, models: List[str]) -> bool:
    """Save model names to a file (one per line)."""
    try:
        path = Path(filepath)
        with open(path, 'w') as f:
            f.write("# Ollama Models of Interest\n")
            f.write("# One model per line, lines starting with # are ignored\n\n")
            for model in models:
                f.write(f"{model}\n")
        return True
    except Exception as e:
        console.print(f"[red]Error writing file: {e}[/red]")
        return False


def display_models_table(models: List[Dict]):
    """Display models in a formatted table."""
    table = Table(title="Ollama Model Information", show_lines=True)
    
    table.add_column("Model", style="cyan", no_wrap=True)
    table.add_column("Context", style="magenta")
    table.add_column("Variants", style="green")
    table.add_column("Capabilities", style="yellow")
    table.add_column("Description", style="white", max_width=40)
    
    for model in models:
        variants_str = "\n".join([
            f"{v['name']} ({v['size']})" 
            for v in model.get('variants', [])[:5]  # Show first 5 variants
        ])
        
        if len(model.get('variants', [])) > 5:
            variants_str += f"\n... +{len(model['variants']) - 5} more"
        
        capabilities_str = ", ".join(model.get('capabilities', ['Text']))
        
        table.add_row(
            model['name'],
            model.get('context_window', 'Unknown'),
            variants_str if variants_str else "N/A",
            capabilities_str,
            model.get('description', 'No description')[:100]
        )
    
    console.print(table)


def display_models_json(models: List[Dict]):
    """Display models in JSON format."""
    console.print_json(data=models)


def interactive_download(models: List[Dict], ollama_container: str = "ollama"):
    """Interactive model download selection."""
    console.print("\n[bold cyan]Select models to download:[/bold cyan]")
    
    selected_models = []
    
    for idx, model in enumerate(models, 1):
        console.print(f"\n[bold]{idx}. {model['name']}[/bold]")
        console.print(f"   Context: {model.get('context_window', 'Unknown')}")
        console.print(f"   Capabilities: {', '.join(model.get('capabilities', ['Text']))}")
        
        if model.get('variants'):
            console.print(f"   Available variants:")
            for v_idx, variant in enumerate(model['variants'], 1):
                console.print(f"      {v_idx}. {variant['name']} - {variant['size']}")
            
            if Confirm.ask(f"   Download a variant of {model['name']}?"):
                variant_choice = Prompt.ask(
                    "   Enter variant number",
                    choices=[str(i) for i in range(1, len(model['variants']) + 1)]
                )
                variant = model['variants'][int(variant_choice) - 1]
                selected_models.append(variant['name'])
    
    if not selected_models:
        console.print("[yellow]No models selected.[/yellow]")
        return
    
    console.print("\n[bold green]Selected models:[/bold green]")
    for model in selected_models:
        console.print(f"  - {model}")
    
    if Confirm.ask("\nProceed with download?"):
        import subprocess
        
        for model in selected_models:
            console.print(f"\n[cyan]Pulling {model}...[/cyan]")
            cmd = f"docker exec -it {ollama_container} ollama pull {model}"
            
            try:
                result = subprocess.run(cmd, shell=True, check=True)
                console.print(f"[green]✓ Successfully pulled {model}[/green]")
            except subprocess.CalledProcessError as e:
                console.print(f"[red]✗ Failed to pull {model}: {e}[/red]")


def main():
    parser = argparse.ArgumentParser(
        description="Fetch Ollama model information and optionally download models"
    )
    parser.add_argument(
        '--config', '-c',
        default='models_of_interest.txt',
        help='File containing model names (one per line)'
    )
    parser.add_argument(
        '--models', '-m',
        nargs='+',
        help='Model names to fetch (space-separated)'
    )
    parser.add_argument(
        '--download', '-d',
        action='store_true',
        help='Enable interactive download mode'
    )
    parser.add_argument(
        '--format', '-f',
        choices=['table', 'json'],
        default='table',
        help='Output format'
    )
    parser.add_argument(
        '--container',
        default='ollama',
        help='Ollama container name (default: ollama)'
    )
    parser.add_argument(
        '--create-config',
        action='store_true',
        help='Create a sample config file'
    )
    
    args = parser.parse_args()
    
    # Create sample config file if requested
    if args.create_config:
        sample_models = [
            'qwen2.5-vl',
            'deepseek-r1',
            'llama3.1',
            'llama3.2-vision',
            'mistral',
            'gpt-oss'
        ]
        if save_models_to_file(args.config, sample_models):
            console.print(f"[green]Created sample config file: {args.config}[/green]")
        return
    
    # Get model names from command line or file
    model_names = args.models if args.models else load_models_from_file(args.config)
    
    if not model_names:
        console.print("[yellow]No models specified. Use --models or --config[/yellow]")
        console.print("Tip: Use --create-config to create a sample file")
        return
    
    # Fetch model information
    fetcher = OllamaModelFetcher()
    models = fetcher.search_models(model_names)
    
    if not models:
        console.print("[red]No model information retrieved.[/red]")
        return
    
    # Display results
    if args.format == 'json':
        display_models_json(models)
    else:
        display_models_table(models)
    
    # Interactive download
    if args.download:
        interactive_download(models, args.container)


if __name__ == "__main__":
    main()
