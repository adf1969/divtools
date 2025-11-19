# Moodle Course Development Best Practices

**Last Updated:** November 16, 2025

**Purpose:** This document provides a comprehensive framework for creating structured, educational Moodle courses using the Moodle Web Services API. It serves as a template for LLM-assisted course creation across any technology domain.

---

## Table of Contents
1. [Moodle API Overview](#moodle-api-overview)
2. [Course Architecture Framework](#course-architecture-framework)
3. [Content Structure Standards](#content-structure-standards)
4. [Assessment & Testing Strategies](#assessment--testing-strategies)
5. [Resource Integration](#resource-integration)
6. [Learning Path Design](#learning-path-design)
7. [API Implementation Guide](#api-implementation-guide)
8. [Course Template Structure](#course-template-structure)
9. [Quality Assurance Checklist](#quality-assurance-checklist)
10. [Example: Docker App Development Course](#example-docker-app-development-course)

---

## Moodle API Overview

### What is Moodle Web Services?

Moodle provides a **REST API** (and SOAP, XML-RPC) for programmatic course creation and management. The API allows:
- ✅ Course creation and configuration
- ✅ Section/module/activity management
- ✅ User enrollment and role assignment
- ✅ Content upload (files, videos, documents)
- ✅ Quiz/assignment creation
- ✅ Grading and completion tracking
- ✅ Forum and discussion management

### Key API Endpoints

**Course Management:**
- `core_course_create_courses` - Create new courses
- `core_course_update_courses` - Update course settings
- `core_course_get_courses` - Retrieve course information
- `core_course_delete_courses` - Delete courses

**Content Management:**
- `core_course_create_categories` - Create course categories
- `core_course_update_course` - Update course content
- `mod_resource_add_instance` - Add resources (files, URLs)
- `mod_page_add_instance` - Add HTML pages
- `mod_url_add_instance` - Add external links

**Assessment:**
- `mod_quiz_add_instance` - Create quizzes
- `mod_assign_add_instance` - Create assignments
- `core_question_create_questions` - Create question bank

**User Management:**
- `enrol_manual_enrol_users` - Enroll users in courses
- `core_role_assign_roles` - Assign roles (student, teacher)

**Progress Tracking:**
- `core_completion_get_activities_completion_status` - Check completion
- `core_completion_update_activity_completion_status_manually` - Mark complete

### Authentication

```bash
# Moodle uses token-based authentication
curl "https://moodle.example.com/webservice/rest/server.php" \
  -d "wstoken=YOUR_TOKEN_HERE" \
  -d "wsfunction=core_course_get_courses" \
  -d "moodlewsrestformat=json"
```

### API Access Requirements

1. **Enable Web Services:**
   - Site Administration → Advanced Features → Enable web services
   
2. **Create Web Service:**
   - Site Administration → Plugins → Web services → External services → Add
   - Add required functions to the service
   
3. **Generate Token:**
   - Site Administration → Plugins → Web services → Manage tokens
   - Create token for specific user and service

4. **Grant Capabilities:**
   - User must have appropriate permissions (create courses, manage content, etc.)

---

## Course Architecture Framework

### Hierarchical Structure

```
Course Category (e.g., "Software Development")
  └── Course (e.g., "Docker Application Development")
       ├── Section 1: Introduction & Fundamentals
       │    ├── Topic 1.1: Overview
       │    ├── Topic 1.2: Prerequisites
       │    ├── Quiz 1: Knowledge Check
       │    └── Assignment 1: Environment Setup
       ├── Section 2: Core Concepts
       │    ├── Topic 2.1: Concept A
       │    ├── Topic 2.2: Concept B
       │    ├── Hands-On Lab 2.1
       │    └── Quiz 2: Comprehension Check
       ├── Section 3: Advanced Topics
       ├── Section 4: Practical Projects
       └── Final Assessment
```

### Section Naming Convention

**Standard Format:** `Section [#]: [Title] - [Learning Goal]`

**Examples:**
- `Section 1: Introduction - Understanding the Fundamentals`
- `Section 2: Docker Basics - Building Your First Container`
- `Section 3: Kubernetes Deployment - Orchestrating at Scale`

### Activity Types per Section

Each section should include:
1. **Instructional Content** (40-50%)
   - Text pages with explanations
   - Embedded videos
   - External resources (documentation links)
   - Downloadable files (PDFs, code samples)

2. **Interactive Activities** (30-40%)
   - Hands-on labs
   - Code exercises
   - Discussion forums
   - Peer review assignments

3. **Assessments** (10-20%)
   - Knowledge checks (ungraded quizzes)
   - Graded quizzes
   - Assignments
   - Projects

---

## Content Structure Standards

### Topic Page Template

Every topic should follow this structure:

#### 1. **Learning Objectives** (SMART Format)
```markdown
By the end of this topic, you will be able to:
- [ ] Specific objective 1 (actionable verb)
- [ ] Specific objective 2 (measurable outcome)
- [ ] Specific objective 3 (practical application)
```

#### 2. **Prerequisites**
```markdown
Before starting this topic, ensure you have:
- ✅ Completed: Section X, Topic Y
- ✅ Knowledge of: Concept A, Concept B
- ✅ Tools installed: Software C, Platform D
```

#### 3. **Estimated Time**
```markdown
⏱️ Estimated completion time: 45-60 minutes
  - Reading: 15 minutes
  - Video: 20 minutes
  - Hands-on practice: 20-25 minutes
```

#### 4. **Content Sections**

**a) Introduction (Why This Matters)**
```markdown
## Introduction

[Brief paragraph explaining the real-world relevance and importance]

**Key Question:** Why do professionals use [this technology/concept]?
**Answer:** [Practical business/technical reason]
```

**b) Concept Explanation**
```markdown
## Core Concepts

### What is [Technology/Concept]?

[Clear definition with analogy]

**Analogy:** Think of it like [everyday comparison]

### How Does It Work?

[Step-by-step explanation with diagrams]

1. Step one explanation
2. Step two explanation
3. Step three explanation
```

**c) Visual Aids**
```markdown
### Architecture Diagram

[Include or link to diagram showing the concept visually]

### Code Example

```language
# Well-commented code example
# Explanation of what this does
code_here()
```
```

**d) Hands-On Practice**
```markdown
## Try It Yourself

**Exercise:** [Clear instructions for hands-on practice]

### Step-by-Step Instructions:

1. **Setup:**
   ```bash
   # Commands to run
   ```

2. **Implementation:**
   ```bash
   # More commands
   ```

3. **Verification:**
   ```bash
   # Check your work
   ```

**Expected Output:**
```
[Show what success looks like]
```

**Troubleshooting:**
- **Issue:** Error message X
  - **Solution:** Fix Y
```

**e) Best Practices**
```markdown
## Best Practices

✅ **DO:**
- Practice 1 with explanation
- Practice 2 with explanation

❌ **DON'T:**
- Anti-pattern 1 with explanation
- Anti-pattern 2 with explanation
```

**f) Additional Resources**
```markdown
## Learn More

📚 **Documentation:**
- [Official Docs](link) - Description

🎥 **Video Tutorials:**
- [Tutorial Title](link) - Duration, description

📖 **Articles:**
- [Article Title](link) - Description

💡 **Tips:**
- Quick tip 1
- Quick tip 2
```

**g) Knowledge Check**
```markdown
## Check Your Understanding

Before moving on, can you answer these questions?

1. Question about key concept 1
2. Question about practical application
3. Question about best practices

[Link to quiz or discussion forum]
```

#### 5. **Next Steps**
```markdown
## What's Next?

Now that you understand [current topic], you're ready for:
- ➡️ [Next Topic Title] - Building on this foundation
- 🔄 Review: [Related Topic] if you need clarification

**Optional Challenge:** [Advanced exercise for motivated learners]
```

---

## Assessment & Testing Strategies

### Quiz Types & Purposes

#### 1. **Pre-Assessment Quiz** (Section 0)
**Purpose:** Identify knowledge gaps and recommend learning path

**Structure:**
- 10-15 questions covering all major topics
- Multiple choice, true/false
- Ungraded or low-stakes
- Results provide personalized recommendations

**Example Questions:**
```
Q1: What is Docker used for?
   a) Database management
   b) Application containerization ✓
   c) Network security
   d) Version control

Q2: Have you used Kubernetes before?
   a) Yes, in production
   b) Yes, for learning
   c) No, but I've heard of it
   d) No, what is it?
```

#### 2. **Knowledge Check Quiz** (After Each Topic)
**Purpose:** Reinforce learning immediately after content consumption

**Structure:**
- 3-5 questions per topic
- Ungraded or participation credit only
- Immediate feedback with explanations
- Unlimited attempts allowed

**Question Design:**
```
Question: [Specific concept from topic]

Feedback (Correct):
"✅ Correct! [Explanation reinforcing the concept]"

Feedback (Incorrect):
"❌ Not quite. [Hint pointing to relevant content section]
Review: [Link to specific content]"
```

#### 3. **Section Comprehension Quiz** (End of Section)
**Purpose:** Assess understanding of entire section

**Structure:**
- 10-15 questions covering all topics in section
- Graded (10-15% of final grade per section)
- 2 attempts allowed
- Must score 70% to proceed

**Question Types:**
- Multiple choice (40%)
- True/False (20%)
- Matching (20%)
- Fill-in-the-blank (20%)

#### 4. **Practical Assessment** (Hands-On)
**Purpose:** Demonstrate practical application

**Structure:**
- Scenario-based problem
- Step-by-step submission (screenshots, code, config files)
- Rubric-based grading
- Peer review option

**Example Assignment:**
```
Title: "Build and Deploy a Containerized Application"

Objective:
Create a Docker container for a Python web application and deploy it.

Requirements:
1. Write a Dockerfile (30 points)
2. Create docker-compose.yml (20 points)
3. Document your process (20 points)
4. Deploy and provide proof (30 points)

Submission:
- GitHub repository link
- Screenshots of running container
- README with setup instructions

Rubric:
[Detailed scoring criteria]
```

#### 5. **Final Exam/Project** (End of Course)
**Purpose:** Comprehensive assessment of all learning objectives

**Options:**

**Option A: Comprehensive Quiz**
- 50-75 questions across all sections
- Multiple formats (MC, T/F, short answer)
- 90 minutes time limit
- 1 attempt
- 25-30% of final grade

**Option B: Capstone Project**
- Real-world scenario
- Integrates multiple concepts
- Multi-week timeline
- Detailed rubric
- 30-40% of final grade

**Option C: Hybrid**
- Quiz (50%) + Practical project (50%)

### Grading Breakdown Template

```
Course Grade Calculation:
├── Section Quizzes (40%)
│   ├── Section 1 Quiz: 8%
│   ├── Section 2 Quiz: 8%
│   ├── Section 3 Quiz: 8%
│   ├── Section 4 Quiz: 8%
│   └── Section 5 Quiz: 8%
├── Practical Assignments (30%)
│   ├── Lab 1: 6%
│   ├── Lab 2: 6%
│   ├── Lab 3: 6%
│   ├── Lab 4: 6%
│   └── Lab 5: 6%
├── Participation (10%)
│   ├── Discussion forums: 5%
│   └── Knowledge checks: 5%
└── Final Assessment (20%)
    └── Capstone project or final exam

Passing Grade: 70%
Honor Grade: 90%+
```

---

## Resource Integration

### Multimedia Content Strategy

#### Video Content
**Best Practices:**
- **Duration:** 5-15 minutes per video (attention span optimal)
- **Placement:** After text introduction, before hands-on
- **Format:** Embedded (YouTube, Vimeo) or uploaded
- **Accessibility:** Include captions/transcripts

**Video Types:**
1. **Concept Explainer** - Whiteboard animation or slides
2. **Walkthrough** - Screen recording with narration
3. **Expert Interview** - Q&A format
4. **Case Study** - Real-world implementation

**Metadata Template:**
```markdown
### Video: [Title]
🎥 Duration: [X minutes]
👤 Instructor: [Name]
📝 Transcript: [Link]
🔖 Key Timestamps:
  - 0:00 - Introduction
  - 2:15 - Core concept
  - 5:30 - Demo begins
  - 10:45 - Summary
```

#### Documentation Links
**Categories:**
- **Official Docs** - Primary reference material
- **Tutorials** - Step-by-step guides
- **API References** - Technical specifications
- **Community Resources** - Forums, Stack Overflow, Reddit

**Link Format:**
```markdown
📚 [Resource Title](URL)
   - Type: [Documentation/Tutorial/Reference]
   - Level: [Beginner/Intermediate/Advanced]
   - Updated: [Date]
   - Description: [One-sentence summary]
```

#### Downloadable Resources
**File Types:**
- **PDF Guides** - Printable reference sheets
- **Code Samples** - Starter templates
- **Configuration Files** - Example configs
- **Datasets** - Practice data for exercises
- **Cheat Sheets** - Quick reference cards

**Organization:**
```
Course Files/
├── Section1_Resources/
│   ├── 01_Getting_Started_Guide.pdf
│   ├── starter_template.zip
│   └── cheatsheet_docker_commands.pdf
├── Section2_Resources/
└── Course_Wide_Resources/
    ├── glossary.pdf
    └── command_reference.pdf
```

#### Interactive Elements
**Types:**
- **H5P Activities** - Interactive presentations, drag-and-drop
- **Code Editors** - Embedded CodePen, Replit, JSFiddle
- **Sandboxes** - Katacoda, Play with Docker
- **Simulations** - Virtual labs

---

## Learning Path Design

### Progression Models

#### 1. **Linear Path** (Beginner-Friendly)
```
Start → Topic 1 → Topic 2 → Topic 3 → Assessment → Next Section
```
**Use When:**
- Foundational knowledge required
- Concepts build sequentially
- Learners are beginners

**Implementation:**
- Activity completion tracking enabled
- Prerequisites enforced
- Clear "Next" navigation

#### 2. **Modular Path** (Flexible Learning)
```
        ┌─→ Topic A1 ─┐
Start ──┼─→ Topic A2 ─┼─→ Assessment A ──┐
        └─→ Topic A3 ─┘                  │
                                         ├─→ Next Section
        ┌─→ Topic B1 ─┐                  │
        ├─→ Topic B2 ─┼─→ Assessment B ──┘
        └─→ Topic B3 ─┘
```
**Use When:**
- Topics are independent
- Learners have varied backgrounds
- Self-paced learning encouraged

**Implementation:**
- Sections independent
- Optional prerequisites
- Recommended sequence provided

#### 3. **Adaptive Path** (Personalized)
```
Pre-Assessment
    ↓
┌───────────────────────┐
│ Beginner Track        │
│ Intermediate Track    │
│ Advanced Track        │
└───────────────────────┘
    ↓
Converge at Final Project
```
**Use When:**
- Audience skill level varies widely
- Course covers broad spectrum
- Resources allow customization

**Implementation:**
- Conditional activities
- Skill-based grouping
- Multiple assessment versions

### Completion Requirements

**Define Clear Criteria:**
```markdown
## Course Completion Requirements

To earn a course certificate, you must:
- ✅ Complete all required activities (marked with ⭐)
- ✅ Score 70%+ on all section quizzes
- ✅ Submit all graded assignments
- ✅ Complete final assessment with 70%+
- ✅ Participate in at least 5 discussion forum posts

**Time Commitment:**
- Estimated: 40-50 hours total
- Recommended pace: 8-10 hours/week
- Duration: 5-6 weeks

**Certification:**
Upon completion, you will receive:
- Course completion certificate
- Digital badge for LinkedIn/portfolio
- Transcript of grades
```

### Pacing Strategies

#### Self-Paced (Recommended for Online)
```markdown
**Schedule Suggestions:**

Week 1: Sections 0-1 (Introduction & Fundamentals)
Week 2: Section 2 (Core Concepts - Part 1)
Week 3: Section 2 (Core Concepts - Part 2)
Week 4: Section 3 (Advanced Topics)
Week 5: Section 4 (Practical Projects)
Week 6: Final Assessment & Review

**Daily Commitment:** 1-2 hours
**Flexibility:** Complete ahead or extend as needed
```

#### Cohort-Based (Instructor-Led)
```markdown
**Fixed Schedule:**

Week 1 (Jan 15-21):
- Monday: Section 1 opens, live session 6pm EST
- Wednesday: Office hours 12pm EST
- Friday: Section 1 quiz due by 11:59pm

Week 2 (Jan 22-28):
- Monday: Section 2 opens
- Tuesday: Peer review assignment due
- Thursday: Live lab session 6pm EST
```

---

## API Implementation Guide

### Course Creation Workflow

#### Step 1: Create Course Category
```python
# Using Python with requests library
import requests

MOODLE_URL = "https://moodle.example.com"
TOKEN = "your_token_here"

def create_category(name, description, parent=0):
    """Create a course category."""
    endpoint = f"{MOODLE_URL}/webservice/rest/server.php"
    params = {
        'wstoken': TOKEN,
        'wsfunction': 'core_course_create_categories',
        'moodlewsrestformat': 'json',
        'categories[0][name]': name,
        'categories[0][description]': description,
        'categories[0][parent]': parent
    }
    response = requests.post(endpoint, data=params)
    return response.json()

# Create category
category = create_category(
    name="Docker & Container Development",
    description="Courses covering Docker, Kubernetes, and containerized application development"
)
category_id = category[0]['id']
```

#### Step 2: Create Course
```python
def create_course(fullname, shortname, categoryid, summary):
    """Create a new course."""
    endpoint = f"{MOODLE_URL}/webservice/rest/server.php"
    params = {
        'wstoken': TOKEN,
        'wsfunction': 'core_course_create_courses',
        'moodlewsrestformat': 'json',
        'courses[0][fullname]': fullname,
        'courses[0][shortname]': shortname,
        'courses[0][categoryid]': categoryid,
        'courses[0][summary]': summary,
        'courses[0][format]': 'topics',  # Topics format (sections)
        'courses[0][showgrades]': 1,
        'courses[0][enablecompletion]': 1
    }
    response = requests.post(endpoint, data=params)
    return response.json()

# Create course
course = create_course(
    fullname="Docker Application Development - Complete Course",
    shortname="DOCKER_DEV_101",
    categoryid=category_id,
    summary="<p>Master Docker containerization from basics to production deployment.</p>"
)
course_id = course[0]['id']
```

#### Step 3: Create Sections
```python
def create_sections(courseid, num_sections):
    """Create course sections (topics)."""
    endpoint = f"{MOODLE_URL}/webservice/rest/server.php"
    params = {
        'wstoken': TOKEN,
        'wsfunction': 'core_course_edit_section',
        'moodlewsrestformat': 'json',
        'courseid': courseid,
        'numsections': num_sections
    }
    response = requests.post(endpoint, data=params)
    return response.json()

# Create 6 sections
create_sections(course_id, 6)
```

#### Step 4: Add Content to Section
```python
def add_page(courseid, section, name, content):
    """Add an HTML page to a section."""
    endpoint = f"{MOODLE_URL}/webservice/rest/server.php"
    params = {
        'wstoken': TOKEN,
        'wsfunction': 'mod_page_add_instance',
        'moodlewsrestformat': 'json',
        'page[course]': courseid,
        'page[section]': section,
        'page[name]': name,
        'page[intro]': 'Introduction to this topic',
        'page[content]': content,
        'page[visible]': 1
    }
    response = requests.post(endpoint, data=params)
    return response.json()

# Add content page to Section 1
html_content = """
<h2>Docker Fundamentals</h2>
<p>Learn the core concepts of containerization...</p>
<h3>Learning Objectives</h3>
<ul>
  <li>Understand what Docker is and why it's used</li>
  <li>Install Docker on your system</li>
  <li>Run your first container</li>
</ul>
"""

add_page(
    courseid=course_id,
    section=1,
    name="1.1 Introduction to Docker",
    content=html_content
)
```

#### Step 5: Add URL Resource (Video)
```python
def add_url(courseid, section, name, url, description):
    """Add an external URL (e.g., YouTube video) to a section."""
    endpoint = f"{MOODLE_URL}/webservice/rest/server.php"
    params = {
        'wstoken': TOKEN,
        'wsfunction': 'mod_url_add_instance',
        'moodlewsrestformat': 'json',
        'url[course]': courseid,
        'url[section]': section,
        'url[name]': name,
        'url[intro]': description,
        'url[externalurl]': url,
        'url[display]': 0,  # 0=automatic, 5=embed, 6=new window
        'url[visible]': 1
    }
    response = requests.post(endpoint, data=params)
    return response.json()

# Add YouTube video
add_url(
    courseid=course_id,
    section=1,
    name="Video: Docker in 100 Seconds",
    url="https://www.youtube.com/watch?v=Gjnup-PuquQ",
    description="Quick overview of Docker (2m 29s)"
)
```

#### Step 6: Create Quiz
```python
def create_quiz(courseid, section, name, intro):
    """Create a quiz activity."""
    endpoint = f"{MOODLE_URL}/webservice/rest/server.php"
    params = {
        'wstoken': TOKEN,
        'wsfunction': 'mod_quiz_add_instance',
        'moodlewsrestformat': 'json',
        'quiz[course]': courseid,
        'quiz[section]': section,
        'quiz[name]': name,
        'quiz[intro]': intro,
        'quiz[timeopen]': 0,  # Always open
        'quiz[timeclose]': 0,  # No close date
        'quiz[timelimit]': 0,  # No time limit
        'quiz[attempts]': 2,  # 2 attempts allowed
        'quiz[grademethod]': 1,  # Highest grade
        'quiz[questionsperpage]': 5,
        'quiz[grade]': 100
    }
    response = requests.post(endpoint, data=params)
    return response.json()

# Create section quiz
quiz = create_quiz(
    courseid=course_id,
    section=1,
    name="Section 1 Quiz: Docker Fundamentals",
    intro="Test your understanding of Docker basics"
)
quiz_id = quiz['instance']
```

#### Step 7: Add Quiz Questions
```python
def add_quiz_question(quizid, question_data):
    """Add a question to a quiz."""
    # First, create question in question bank
    endpoint = f"{MOODLE_URL}/webservice/rest/server.php"
    params = {
        'wstoken': TOKEN,
        'wsfunction': 'core_question_create_questions',
        'moodlewsrestformat': 'json',
        'contextid': get_course_context_id(course_id),
        'questions[0][qtype]': question_data['type'],  # multichoice, truefalse, essay
        'questions[0][name]': question_data['name'],
        'questions[0][questiontext]': question_data['text'],
        'questions[0][defaultmark]': question_data['points']
    }
    
    # Add answer options for multiple choice
    if question_data['type'] == 'multichoice':
        for i, answer in enumerate(question_data['answers']):
            params[f'questions[0][answer][{i}][text]'] = answer['text']
            params[f'questions[0][answer][{i}][fraction]'] = answer['correct']
    
    response = requests.post(endpoint, data=params)
    return response.json()

# Example question
question = {
    'type': 'multichoice',
    'name': 'Q1_Docker_Definition',
    'text': 'What is Docker primarily used for?',
    'points': 1,
    'answers': [
        {'text': 'Database management', 'correct': 0},
        {'text': 'Application containerization', 'correct': 100},
        {'text': 'Network security', 'correct': 0},
        {'text': 'Version control', 'correct': 0}
    ]
}

add_quiz_question(quiz_id, question)
```

### Bulk Content Upload Script Template

```python
#!/usr/bin/env python3
"""
Moodle Course Builder
Automates course creation from structured data
"""

import json
import requests
from typing import Dict, List

class MoodleCourseBuilder:
    def __init__(self, url: str, token: str):
        self.url = url
        self.token = token
        self.endpoint = f"{url}/webservice/rest/server.php"
    
    def call_api(self, function: str, params: Dict) -> Dict:
        """Generic API call wrapper."""
        data = {
            'wstoken': self.token,
            'wsfunction': function,
            'moodlewsrestformat': 'json'
        }
        data.update(params)
        response = requests.post(self.endpoint, data=data)
        return response.json()
    
    def build_course_from_json(self, course_json: str):
        """Build entire course from JSON structure."""
        with open(course_json, 'r') as f:
            course_data = json.load(f)
        
        # Create category
        category_id = self.create_category(course_data['category'])
        
        # Create course
        course_id = self.create_course(course_data['course'], category_id)
        
        # Create sections and content
        for section_num, section in enumerate(course_data['sections'], 1):
            self.populate_section(course_id, section_num, section)
        
        print(f"✅ Course created successfully! ID: {course_id}")
        return course_id

# Example JSON structure
course_structure = {
    "category": {
        "name": "Docker Development",
        "description": "Container and orchestration courses"
    },
    "course": {
        "fullname": "Docker App Development",
        "shortname": "DOCKER_101",
        "summary": "Complete Docker course"
    },
    "sections": [
        {
            "name": "Introduction",
            "summary": "Get started with Docker",
            "activities": [
                {
                    "type": "page",
                    "name": "Welcome",
                    "content": "<h2>Welcome!</h2>..."
                },
                {
                    "type": "url",
                    "name": "Video Tutorial",
                    "url": "https://youtube.com/..."
                },
                {
                    "type": "quiz",
                    "name": "Knowledge Check",
                    "questions": [...]
                }
            ]
        }
    ]
}
```

---

## Course Template Structure

### JSON Course Definition Schema

```json
{
  "metadata": {
    "title": "Docker Application Development",
    "version": "1.0",
    "author": "Your Name",
    "created": "2025-11-16",
    "updated": "2025-11-16",
    "duration_hours": 40,
    "level": "Beginner to Intermediate",
    "prerequisites": [
      "Basic Linux command line knowledge",
      "Basic programming experience"
    ],
    "learning_outcomes": [
      "Build and deploy containerized applications",
      "Understand Docker architecture and best practices",
      "Deploy applications to Kubernetes"
    ]
  },
  
  "course_settings": {
    "category": "Software Development",
    "format": "topics",
    "numsections": 6,
    "enable_completion": true,
    "show_grades": true,
    "start_date": "2025-01-15",
    "end_date": null,
    "enrollment": "self"
  },
  
  "grading_scheme": {
    "passing_grade": 70,
    "components": [
      {
        "name": "Section Quizzes",
        "weight": 40,
        "items": [
          {"section": 1, "weight": 8},
          {"section": 2, "weight": 8},
          {"section": 3, "weight": 8},
          {"section": 4, "weight": 8},
          {"section": 5, "weight": 8}
        ]
      },
      {
        "name": "Practical Assignments",
        "weight": 30,
        "items": [
          {"name": "Lab 1", "weight": 10},
          {"name": "Lab 2", "weight": 10},
          {"name": "Lab 3", "weight": 10}
        ]
      },
      {
        "name": "Participation",
        "weight": 10
      },
      {
        "name": "Final Project",
        "weight": 20
      }
    ]
  },
  
  "sections": [
    {
      "section_number": 0,
      "title": "Course Overview & Prerequisites",
      "summary": "Welcome and preparation",
      "activities": [
        {
          "type": "page",
          "name": "Welcome to the Course",
          "content_file": "content/section0/welcome.html",
          "completion": "view"
        },
        {
          "type": "page",
          "name": "How to Use This Course",
          "content_file": "content/section0/how_to_use.html",
          "completion": "view"
        },
        {
          "type": "quiz",
          "name": "Pre-Assessment",
          "questions_file": "quizzes/section0_preassessment.json",
          "attempts": 1,
          "graded": false,
          "completion": "complete"
        }
      ]
    },
    {
      "section_number": 1,
      "title": "Docker Fundamentals",
      "summary": "Introduction to containerization",
      "estimated_hours": 8,
      "activities": [
        {
          "type": "page",
          "name": "1.1 What is Docker?",
          "content_file": "content/section1/topic1_1.html",
          "completion": "view"
        },
        {
          "type": "url",
          "name": "Video: Docker in 100 Seconds",
          "url": "https://www.youtube.com/watch?v=Gjnup-PuquQ",
          "description": "Quick overview (2m 29s)",
          "display": "embed",
          "completion": "view"
        },
        {
          "type": "page",
          "name": "1.2 Installing Docker",
          "content_file": "content/section1/topic1_2.html",
          "completion": "view"
        },
        {
          "type": "assign",
          "name": "Lab 1: Your First Container",
          "instructions_file": "assignments/lab1.html",
          "due_days": 7,
          "grade": 10,
          "submission_types": ["file", "online_text"],
          "completion": "submit"
        },
        {
          "type": "quiz",
          "name": "Section 1 Quiz",
          "questions_file": "quizzes/section1_quiz.json",
          "attempts": 2,
          "time_limit": 30,
          "grade": 8,
          "completion": "pass"
        },
        {
          "type": "forum",
          "name": "Discussion: Docker Use Cases",
          "description": "Share your ideas for using Docker",
          "completion": "post"
        }
      ]
    }
  ]
}
```

### Content File Organization

```
moodle_course_content/
├── course_definition.json          # Main course structure
├── README.md                        # Course build instructions
├── content/                         # HTML content files
│   ├── section0/
│   │   ├── welcome.html
│   │   └── how_to_use.html
│   ├── section1/
│   │   ├── topic1_1.html
│   │   ├── topic1_2.html
│   │   └── topic1_3.html
│   └── section2/
├── quizzes/                         # Quiz definitions (JSON)
│   ├── section0_preassessment.json
│   ├── section1_quiz.json
│   └── section2_quiz.json
├── assignments/                     # Assignment instructions
│   ├── lab1.html
│   ├── lab1_rubric.json
│   ├── lab2.html
│   └── project_final.html
├── resources/                       # Downloadable files
│   ├── docker_cheatsheet.pdf
│   ├── sample_dockerfile.txt
│   └── starter_code.zip
└── scripts/
    ├── build_course.py             # Course builder script
    ├── validate_structure.py       # Validate JSON
    └── requirements.txt            # Python dependencies
```

---

## Quality Assurance Checklist

### Pre-Launch Review

**Content Quality:**
- [ ] All learning objectives are SMART (Specific, Measurable, Achievable, Relevant, Time-bound)
- [ ] Content is accurate and up-to-date
- [ ] No broken links or missing resources
- [ ] All videos have working embeds
- [ ] Code examples are tested and functional
- [ ] Spelling and grammar checked
- [ ] Accessibility: Alt text for images, captions for videos
- [ ] Mobile-responsive layout verified

**Course Structure:**
- [ ] Logical progression of topics
- [ ] Clear navigation between sections
- [ ] Completion tracking enabled for all activities
- [ ] Prerequisites properly configured
- [ ] Estimated time provided for each section
- [ ] Consistent formatting throughout

**Assessments:**
- [ ] Quiz questions have correct answers marked
- [ ] Feedback provided for all answer options
- [ ] Quiz settings configured (attempts, time limits)
- [ ] Grading rubrics created for assignments
- [ ] Grade weighting adds up to 100%
- [ ] Passing criteria clearly stated

**User Experience:**
- [ ] Course introduction/welcome message clear
- [ ] Instructions for activities are unambiguous
- [ ] Help resources provided (FAQs, support contact)
- [ ] Discussion forums set up and moderated
- [ ] Sample submissions provided where helpful
- [ ] Certificate of completion configured

**Technical:**
- [ ] All API calls successful
- [ ] Files uploaded correctly
- [ ] Permissions set appropriately
- [ ] Backup of course created
- [ ] Test user enrollment works
- [ ] Mobile app compatibility tested

### Post-Launch Monitoring

**Week 1:**
- Monitor enrollment numbers
- Check for technical issues reported
- Review first quiz completion rates
- Address any content questions in forums

**Week 2-4:**
- Analyze quiz/assignment results
- Identify common mistakes (update content/FAQs)
- Collect learner feedback
- Update content based on feedback

**End of Course:**
- Survey learners (satisfaction, difficulty, improvements)
- Review completion rates
- Analyze grade distribution
- Plan course updates based on data

---

## Example: Docker App Development Course

### Complete Course Outline

```markdown
# Docker Application Development - Complete Course

## Course Information
- **Level:** Beginner to Intermediate
- **Duration:** 40-50 hours (6-8 weeks)
- **Format:** Self-paced with optional weekly check-ins
- **Prerequisites:** Basic Linux CLI, basic programming
- **Certificate:** Yes, upon 70%+ completion

---

## Section 0: Getting Started (2 hours)

### Activities:
1. **Page:** Welcome & Course Overview
2. **Page:** How to Use This Course
3. **Page:** Prerequisites Checklist
4. **Quiz:** Pre-Assessment (ungraded)
5. **Forum:** Introduce Yourself

### Learning Objectives:
- Understand course structure and requirements
- Verify prerequisite knowledge
- Set up learning environment

---

## Section 1: Docker Fundamentals (8 hours)

### Topics:
1.1 **What is Docker?**
   - Containers vs VMs
   - Docker architecture
   - Use cases and benefits
   
1.2 **Installing Docker**
   - Installation on Windows/Mac/Linux
   - Docker Desktop vs Docker Engine
   - Verifying installation
   
1.3 **First Container**
   - Running docker run
   - Container lifecycle
   - Basic commands (ps, stop, rm)
   
1.4 **Images and Registries**
   - Docker Hub
   - Pulling and pushing images
   - Image layers

### Activities:
- **Videos:** 4 tutorials (total 45 min)
- **Hands-On:** Lab 1 - Run your first container
- **Quiz:** Section 1 Knowledge Check (8% of grade)
- **Discussion:** Real-world Docker use cases

### Resources:
- Docker official documentation links
- Cheat sheet: Basic Docker commands
- Troubleshooting guide

---

## Section 2: Building Docker Images (10 hours)

### Topics:
2.1 **Dockerfile Basics**
   - FROM, RUN, COPY, CMD
   - Building images
   - Best practices
   
2.2 **Multi-Stage Builds**
   - Why multi-stage?
   - Optimization techniques
   - Example: Python app
   
2.3 **Docker Compose**
   - YAML syntax
   - Multi-container apps
   - Networks and volumes
   
2.4 **.dockerignore**
   - Reducing build context
   - Security considerations

### Activities:
- **Videos:** 5 tutorials (total 1.5 hours)
- **Hands-On:** Lab 2 - Build a web application container
- **Assignment:** Create Dockerfile for your own project (10% of grade)
- **Quiz:** Section 2 Quiz (8% of grade)

### Resources:
- Dockerfile reference
- Multi-stage build examples
- docker-compose.yml templates

---

## Section 3: Container Orchestration (10 hours)

### Topics:
3.1 **Introduction to Kubernetes**
   - Why orchestration?
   - K8s architecture
   - Pods, services, deployments
   
3.2 **K3s Lightweight Kubernetes**
   - Installing K3s
   - kubectl basics
   - First deployment
   
3.3 **Deployments and Services**
   - Creating deployments
   - Exposing services
   - Scaling applications
   
3.4 **ConfigMaps and Secrets**
   - Configuration management
   - Secret storage
   - Environment variables

### Activities:
- **Videos:** 6 tutorials (total 2 hours)
- **Hands-On:** Lab 3 - Deploy to K3s
- **Project:** Multi-container app on Kubernetes (10% of grade)
- **Quiz:** Section 3 Quiz (8% of grade)

---

## Section 4: Production Best Practices (8 hours)

### Topics:
4.1 **Security**
   - Image scanning
   - Least privilege
   - Secrets management
   
4.2 **Logging and Monitoring**
   - Container logs
   - Prometheus metrics
   - Grafana dashboards
   
4.3 **CI/CD Integration**
   - GitHub Actions
   - Automated builds
   - Deployment pipelines
   
4.4 **Performance Optimization**
   - Resource limits
   - Health checks
   - Caching strategies

### Activities:
- **Videos:** 5 tutorials (total 1.5 hours)
- **Hands-On:** Lab 4 - Set up monitoring
- **Assignment:** Security audit of container (10% of grade)
- **Quiz:** Section 4 Quiz (8% of grade)

---

## Section 5: Real-World Projects (10 hours)

### Topics:
5.1 **Project Planning**
   - Architecture design
   - Technology selection
   - Documentation
   
5.2 **Implementation**
   - Building the application
   - Writing Dockerfiles
   - Creating K8s manifests
   
5.3 **Testing**
   - Unit tests in containers
   - Integration testing
   - Performance testing
   
5.4 **Deployment**
   - Production deployment
   - Monitoring setup
   - Troubleshooting

### Activities:
- **Capstone Project:** Build and deploy complete application (20% of grade)
- **Peer Review:** Review classmate's project
- **Presentation:** Demo your project (video or live)

### Project Requirements:
- Multi-container application
- Docker Compose for development
- K8s deployment manifests
- CI/CD pipeline
- Monitoring and logging
- Documentation (README, architecture diagram)

---

## Section 6: Final Assessment (2 hours)

### Activities:
1. **Final Quiz:** Comprehensive assessment (20% of grade)
   - 50 questions covering all sections
   - 90-minute time limit
   - 1 attempt
   
2. **Course Reflection:** Written reflection on learning
3. **Course Survey:** Feedback for improvement
4. **Certificate:** Download upon completion

---

## Grading Summary

| Component | Weight | Details |
|-----------|--------|---------|
| Section Quizzes | 40% | 5 quizzes @ 8% each |
| Practical Labs | 30% | 4 labs @ 7.5% each |
| Participation | 10% | Forums, peer reviews |
| Final Project | 20% | Capstone application |
| **Total** | **100%** | **Passing: 70%** |

---

## Additional Resources

### Recommended YouTube Channels:
- TechWorld with Nana
- Fireship
- NetworkChuck
- freeCodeCamp

### Documentation:
- [Docker Docs](https://docs.docker.com/)
- [Kubernetes Docs](https://kubernetes.io/docs/)
- [K3s Docs](https://docs.k3s.io/)

### Community:
- Docker Community Forums
- Stack Overflow
- Reddit: r/docker, r/kubernetes
- Discord: Docker Community Server

### Tools:
- Docker Desktop
- VS Code with Docker extension
- kubectl
- Lens (Kubernetes IDE)
```

---

## Using This Template with LLMs

### Prompt Template for Course Creation

```
I need to create a Moodle course on [TOPIC].

Please use the MOODLE-COURSE-BEST-PRACTICES.md document as a framework and create:

1. **Course Structure JSON**
   - Complete course definition following the JSON schema
   - [X] sections covering [list major topics]
   - Appropriate mix of activities (pages, videos, quizzes, assignments)

2. **Content Outline**
   - Detailed outline for each section
   - Learning objectives (SMART format)
   - Topic breakdown with estimated times

3. **Assessment Strategy**
   - Quiz questions for each section (10-15 questions each)
   - Assignment descriptions with rubrics
   - Final project requirements

4. **Resource List**
   - YouTube videos (with links and timestamps)
   - Documentation links
   - Downloadable resources needed

5. **Implementation Plan**
   - API calls needed for course creation
   - Content file organization
   - Build script outline

**Course Specifications:**
- **Target Audience:** [Beginner/Intermediate/Advanced]
- **Duration:** [X hours/weeks]
- **Prerequisites:** [List]
- **Learning Outcomes:** [List]

**Special Requirements:**
- [Any specific needs]

Please structure the output so I can directly use it to build the course using the Moodle API.
```

### Example LLM Interaction

**User:**
```
Create a Moodle course for "Python FastAPI Development" following the MOODLE-COURSE-BEST-PRACTICES.md template. 
Target audience: Intermediate developers
Duration: 30 hours (4 weeks)
Prerequisites: Python basics, REST API concepts
Focus: Building production-ready APIs
```

**Expected LLM Output:**
- Complete JSON course definition
- Section-by-section content outline
- Quiz questions with answers
- Assignment descriptions
- Resource compilation
- Python script for course creation via API

---

## Maintenance & Updates

### Version Control for Courses

**Track Changes:**
```
Course Version History:
v1.0 (2025-01-15) - Initial launch
v1.1 (2025-02-10) - Updated Section 2 videos, fixed quiz typos
v1.2 (2025-03-15) - Added new lab on Docker Compose
v2.0 (2025-06-01) - Major update: Added Kubernetes section
```

**Update Process:**
1. Collect feedback from learners
2. Identify content gaps or errors
3. Create updated content files
4. Test changes in staging environment
5. Update course version in production
6. Notify enrolled learners of changes

### Content Refresh Schedule

**Quarterly Review:**
- Check all external links (video, documentation)
- Update outdated screenshots or examples
- Refresh statistics or case studies

**Annual Overhaul:**
- Review entire curriculum for relevance
- Update to latest technology versions
- Add new topics based on industry trends
- Revise assessments based on learner performance data

---

## Conclusion

This framework provides a comprehensive approach to creating high-quality Moodle courses that can be automated via the Web Services API. By following these best practices, you can:

✅ Create structured, pedagogically sound courses  
✅ Leverage LLMs for rapid content generation  
✅ Ensure consistent quality across all course materials  
✅ Scale course creation efficiently  
✅ Maintain and update courses systematically  

**Next Steps:**
1. Review this document and adapt to your specific needs
2. Set up Moodle Web Services API access
3. Gather course content (videos, documentation, exercises)
4. Use LLM with this template to generate course structure
5. Build course using provided API scripts
6. Test with pilot users
7. Launch and iterate based on feedback

---

**Document Status:** Living document - update as standards evolve  
**Last Updated:** November 16, 2025  
**Next Review:** February 16, 2026  
**Maintainer:** Course Development Team
