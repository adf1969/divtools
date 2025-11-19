"""
Unit tests for AI analyzer (with mocked API calls)
Last Updated: 11/14/2025 12:00:00 PM CDT
"""

import pytest
from unittest.mock import Mock, patch, MagicMock
from dthostmon.core.ai_analyzer import AIAnalyzer, AIAnalysisError


@pytest.fixture
def ai_config():
    """AI configuration for testing"""
    return {
        'primary_model': 'grok',
        'fallback_model': 'ollama',
        'grok': {
            'api_key': 'test_key',
            'api_url': 'https://api.x.ai/v1',
            'model_name': 'grok-beta'
        },
        'ollama': {
            'host': 'http://localhost:11434',
            'model': 'llama3.1'
        }
    }


def test_ai_analyzer_initialization(ai_config):
    """Test AIAnalyzer initialization"""
    analyzer = AIAnalyzer(ai_config)
    
    assert analyzer.primary_model == 'grok'
    assert analyzer.fallback_model == 'ollama'
    assert analyzer.grok_api_key == 'test_key'


@patch('dthostmon.core.ai_analyzer.requests.post')
def test_analyze_logs_with_grok(mock_post, ai_config, sample_host_data, sample_log_data):
    """Test log analysis using Grok API"""
    # Mock Grok API response
    mock_response = Mock()
    mock_response.json.return_value = {
        'choices': [{
            'message': {
                'content': '''```json
{
    "health_score": 95,
    "severity": "INFO",
    "anomalies": [],
    "summary": "System healthy, no issues detected",
    "recommendations": "Continue monitoring"
}
```'''
            }
        }]
    }
    mock_response.raise_for_status = Mock()
    mock_post.return_value = mock_response
    
    analyzer = AIAnalyzer(ai_config)
    result = analyzer.analyze_logs(sample_host_data, sample_log_data)
    
    assert result['health_score'] == 95
    assert result['severity'] == 'INFO'
    assert 'summary' in result


@patch('dthostmon.core.ai_analyzer.requests.post')
def test_analyze_logs_fallback_to_ollama(mock_post, ai_config, sample_host_data, sample_log_data):
    """Test fallback to Ollama when Grok fails"""
    # First call (Grok) fails
    mock_post.side_effect = [
        Exception("Grok API failed"),
        Mock(json=lambda: {'response': '{"health_score": 80, "severity": "WARN", "summary": "Issues detected"}'},
             raise_for_status=Mock())
    ]
    
    analyzer = AIAnalyzer(ai_config)
    result = analyzer.analyze_logs(sample_host_data, sample_log_data)
    
    # Should get result from fallback
    assert 'health_score' in result
    assert 'summary' in result


def test_fallback_analysis(ai_config, sample_host_data, sample_log_data):
    """Test fallback analysis when all AI models fail"""
    analyzer = AIAnalyzer(ai_config)
    result = analyzer._fallback_analysis(sample_host_data, sample_log_data)
    
    assert result['health_score'] == 80
    assert result['severity'] == 'INFO'
    assert 'AI analysis unavailable' in result['summary']


def test_parse_analysis_response_with_markdown(ai_config):
    """Test parsing JSON response from markdown code block"""
    analyzer = AIAnalyzer(ai_config)
    
    response = '''```json
{
    "health_score": 90,
    "severity": "INFO",
    "anomalies": [],
    "summary": "Test summary"
}
```'''
    
    result = analyzer._parse_analysis_response(response)
    
    assert result['health_score'] == 90
    assert result['severity'] == 'INFO'


def test_parse_analysis_response_plain_json(ai_config):
    """Test parsing plain JSON response"""
    analyzer = AIAnalyzer(ai_config)
    
    response = '{"health_score": 85, "severity": "WARN", "summary": "Warning", "anomalies": []}'
    result = analyzer._parse_analysis_response(response)
    
    assert result['health_score'] == 85
    assert result['severity'] == 'WARN'
