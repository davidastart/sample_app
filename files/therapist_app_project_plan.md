# Therapist Office Application - Project Plan & Architecture

## Executive Summary

This document outlines the architecture and implementation plan for a secure, AI-powered treatment planning application for a private practice therapist's office. The application leverages Oracle Cloud Infrastructure (OCI) Generative AI to recommend evidence-based treatment plans while ensuring patient data privacy and therapist-level access controls.

## 1. Project Overview

### 1.1 Purpose
Create a HIPAA-compliant application that:
- Allows therapists to enter session notes and patient information
- Generates evidence-based treatment plan recommendations using OCI Generative AI
- Maintains strict data isolation between therapists
- Enables office-wide templates for common patient categories
- Ensures patient data is NOT used for LLM training

### 1.2 Key Requirements
- **Security**: HIPAA-compliant, encrypted data storage, role-based access control
- **Privacy**: Data isolation per therapist, no LLM training on patient data
- **AI Integration**: OCI Generative AI (Cohere Command models) for treatment recommendations
- **Infrastructure**: Podman containers on OCI Linux 9 VM
- **Database**: Oracle AI Database 23ai with vector search capabilities
- **Development**: Mac-based development with VS Code, GitHub Desktop workflow

## 2. Application Architecture

### 2.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     User Layer (Web Browser)                │
└─────────────────────────────┬───────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────┐
│           Frontend Container (React/Next.js)                │
│  - Therapist Dashboard                                      │
│  - Patient Session Entry Forms                             │
│  - Treatment Plan Viewer                                   │
└─────────────────────────────┬───────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────┐
│        Backend API Container (Node.js/Python FastAPI)      │
│  - Authentication & Authorization (JWT)                    │
│  - Session Management                                      │
│  - Treatment Plan Generation Logic                        │
│  - RAG Implementation for Evidence-Based Recommendations   │
└─────────────┬───────────────────────────────┬──────────────┘
              │                               │
              ▼                               ▼
┌─────────────────────────┐    ┌────────────────────────────┐
│ Oracle Database 23ai    │    │  OCI Generative AI         │
│ Container               │    │  Service                   │
│                         │    │                            │
│ - Patient Records       │    │  - Cohere Command A        │
│ - Session Notes         │    │  - Vector Embeddings       │
│ - Treatment Plans       │    │  - Treatment Generation    │
│ - Therapist Accounts    │    │                            │
│ - Office Templates      │    │  ** Data Privacy Mode **   │
│ - Vector Embeddings     │    │  (No training on data)     │
└─────────────────────────┘    └────────────────────────────┘
```

### 2.2 Container Architecture (Podman on OCI Linux 9)

```yaml
# Container Structure
therapist-app-network/
├── frontend-container (Port 3000)
├── backend-container (Port 8000)
└── oracle-db-container (Port 1521)
```

## 3. Database Schema

### 3.1 Core Tables

```sql
-- Therapists/Users
CREATE TABLE therapists (
    therapist_id NUMBER PRIMARY KEY,
    email VARCHAR2(255) UNIQUE NOT NULL,
    first_name VARCHAR2(100) NOT NULL,
    last_name VARCHAR2(100) NOT NULL,
    license_number VARCHAR2(50),
    password_hash VARCHAR2(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP
);

-- Patients (linked to specific therapist)
CREATE TABLE patients (
    patient_id NUMBER PRIMARY KEY,
    therapist_id NUMBER NOT NULL,
    first_name VARCHAR2(100) NOT NULL,
    last_name VARCHAR2(100) NOT NULL,
    date_of_birth DATE,
    patient_category VARCHAR2(100), -- e.g., 'anxiety', 'depression', 'trauma'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_patient_therapist FOREIGN KEY (therapist_id) 
        REFERENCES therapists(therapist_id)
);

-- Session Notes
CREATE TABLE session_notes (
    session_id NUMBER PRIMARY KEY,
    patient_id NUMBER NOT NULL,
    therapist_id NUMBER NOT NULL,
    session_date DATE NOT NULL,
    presenting_concerns CLOB,
    symptoms_observed CLOB,
    clinical_observations CLOB,
    risk_assessment CLOB,
    session_summary CLOB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    CONSTRAINT fk_session_patient FOREIGN KEY (patient_id) 
        REFERENCES patients(patient_id),
    CONSTRAINT fk_session_therapist FOREIGN KEY (therapist_id) 
        REFERENCES therapists(therapist_id)
);

-- Treatment Plans
CREATE TABLE treatment_plans (
    plan_id NUMBER PRIMARY KEY,
    patient_id NUMBER NOT NULL,
    therapist_id NUMBER NOT NULL,
    diagnosis_codes VARCHAR2(500), -- ICD-10 codes
    dsm_diagnosis VARCHAR2(500),
    treatment_goals CLOB,
    recommended_interventions CLOB,
    treatment_modality VARCHAR2(100), -- CBT, DBT, Psychodynamic, etc.
    session_frequency VARCHAR2(50),
    estimated_duration VARCHAR2(50),
    ai_generated_recommendations CLOB,
    therapist_notes CLOB,
    status VARCHAR2(20) DEFAULT 'ACTIVE', -- ACTIVE, COMPLETED, DISCONTINUED
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    CONSTRAINT fk_plan_patient FOREIGN KEY (patient_id) 
        REFERENCES patients(patient_id),
    CONSTRAINT fk_plan_therapist FOREIGN KEY (therapist_id) 
        REFERENCES therapists(therapist_id)
);

-- Office-Wide Treatment Templates (accessible to all therapists)
CREATE TABLE treatment_templates (
    template_id NUMBER PRIMARY KEY,
    patient_category VARCHAR2(100) NOT NULL,
    diagnosis_category VARCHAR2(200),
    evidence_based_interventions CLOB,
    typical_treatment_modalities VARCHAR2(500),
    recommended_goals CLOB,
    session_structure CLOB,
    success_indicators CLOB,
    references CLOB, -- Research references
    created_by_therapist_id NUMBER,
    is_office_wide NUMBER(1) DEFAULT 1, -- 1=accessible to all, 0=private
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    CONSTRAINT fk_template_therapist FOREIGN KEY (created_by_therapist_id) 
        REFERENCES therapists(therapist_id)
);

-- Vector Embeddings for RAG (Retrieval-Augmented Generation)
CREATE TABLE evidence_base_documents (
    document_id NUMBER PRIMARY KEY,
    document_type VARCHAR2(50), -- 'DSM_5_TR', 'RESEARCH_ARTICLE', 'TREATMENT_GUIDELINE'
    category VARCHAR2(100), -- Patient category this applies to
    title VARCHAR2(500),
    content CLOB,
    source VARCHAR2(500),
    publication_date DATE,
    embedding VECTOR(1024, FLOAT32), -- For semantic search
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Audit Log for HIPAA Compliance
CREATE TABLE access_audit_log (
    log_id NUMBER PRIMARY KEY,
    therapist_id NUMBER NOT NULL,
    action VARCHAR2(100) NOT NULL, -- 'VIEW', 'CREATE', 'UPDATE', 'DELETE'
    resource_type VARCHAR2(50), -- 'PATIENT', 'SESSION', 'TREATMENT_PLAN'
    resource_id NUMBER,
    ip_address VARCHAR2(45),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_audit_therapist FOREIGN KEY (therapist_id) 
        REFERENCES therapists(therapist_id)
);
```

## 4. Patient Categories & Evidence-Based Treatment Approaches

### 4.1 Common Patient Categories for Private Practice

Based on mental health research and DSM-5-TR classifications:

1. **Anxiety Disorders**
   - Generalized Anxiety Disorder (GAD)
   - Social Anxiety Disorder
   - Panic Disorder
   - Specific Phobias
   - Evidence-based: CBT, Exposure Therapy, Mindfulness-Based Interventions

2. **Depressive Disorders**
   - Major Depressive Disorder
   - Persistent Depressive Disorder (Dysthymia)
   - Evidence-based: CBT, Behavioral Activation, Interpersonal Therapy (IPT)

3. **Trauma and Stressor-Related Disorders**
   - Post-Traumatic Stress Disorder (PTSD)
   - Acute Stress Disorder
   - Adjustment Disorders
   - Evidence-based: Trauma-Focused CBT, EMDR, Prolonged Exposure

4. **Obsessive-Compulsive and Related Disorders**
   - Obsessive-Compulsive Disorder (OCD)
   - Body Dysmorphic Disorder
   - Evidence-based: Exposure and Response Prevention (ERP), CBT

5. **Eating Disorders**
   - Anorexia Nervosa
   - Bulimia Nervosa
   - Binge-Eating Disorder
   - Evidence-based: CBT-E, Family-Based Treatment (FBT), DBT

6. **Substance-Related and Addictive Disorders**
   - Alcohol Use Disorder
   - Substance Use Disorders
   - Evidence-based: Motivational Interviewing, CBT, 12-Step Facilitation

7. **Relationship and Family Issues**
   - Couples Counseling
   - Family Conflict
   - Divorce Adjustment
   - Evidence-based: Emotion-Focused Therapy (EFT), Gottman Method

8. **Personality Disorders**
   - Borderline Personality Disorder
   - Evidence-based: DBT, Mentalization-Based Treatment, Schema Therapy

9. **Attention-Deficit/Hyperactivity Disorder (ADHD)**
   - Adult ADHD
   - Evidence-based: CBT for ADHD, Coaching, Psychoeducation

10. **Life Transitions and Adjustment**
    - Career changes
    - Grief and loss
    - Life stage transitions
    - Evidence-based: Solution-Focused Brief Therapy, Existential Therapy

## 5. OCI Generative AI Integration

### 5.1 Model Selection
- **Primary Model**: Cohere Command A (cohere.command-a-03-2025)
  - Most performant Cohere model
  - Strong multilingual capabilities
  - 256,000 token context length
  - Excellent for complex reasoning tasks

### 5.2 Privacy Configuration
```python
# Python SDK Configuration for OCI Generative AI
# Key Point: OCI does NOT use customer data for training by default

oci_config = {
    "region": "us-ashburn-1",  # Your OCI region
    "compartment_id": "ocid1.compartment...",
    "model_id": "cohere.command-a-03-2025"
}

# Treatment plan generation with privacy
def generate_treatment_plan(session_data, patient_history, office_templates):
    """
    Generate treatment plan using OCI Generative AI.
    Data stays in your tenancy and is NOT used for model training.
    """
    
    # Build RAG context from evidence base
    relevant_evidence = retrieve_relevant_evidence(
        session_data['presenting_concerns'],
        patient_history['diagnosis_category']
    )
    
    # Construct prompt with evidence-based guidelines
    prompt = f"""
    You are a clinical psychologist assistant helping to develop an evidence-based 
    treatment plan. Base your recommendations on established clinical guidelines 
    and the DSM-5-TR.
    
    Patient Information:
    - Presenting Concerns: {session_data['presenting_concerns']}
    - Observed Symptoms: {session_data['symptoms_observed']}
    - Clinical Observations: {session_data['clinical_observations']}
    - Patient Category: {patient_history['category']}
    
    Evidence-Based Guidelines:
    {relevant_evidence}
    
    Office Templates:
    {office_templates}
    
    Please provide:
    1. Recommended DSM-5-TR diagnosis (with ICD-10 codes)
    2. Evidence-based treatment interventions
    3. Specific treatment goals (SMART format)
    4. Recommended treatment modality (CBT, DBT, etc.)
    5. Suggested session frequency and duration
    6. Expected outcomes and success indicators
    7. References to clinical guidelines used
    
    Format the response as a structured treatment plan.
    """
    
    response = generative_ai_client.generate_text(
        model_id=oci_config['model_id'],
        prompt=prompt,
        max_tokens=2000,
        temperature=0.3,  # Lower temperature for more consistent clinical recommendations
        top_p=0.9
    )
    
    return response.data.choices[0].text
```

### 5.3 RAG (Retrieval-Augmented Generation) Implementation

```python
# Vector search for relevant clinical evidence
def retrieve_relevant_evidence(presenting_concerns, diagnosis_category):
    """
    Use Oracle 23ai vector search to find relevant evidence-based guidelines
    """
    
    # Generate embedding for the query
    query_embedding = generate_embedding(
        text=f"{presenting_concerns} {diagnosis_category}"
    )
    
    # Vector similarity search in Oracle 23ai
    sql = """
    SELECT document_id, title, content, source
    FROM evidence_base_documents
    WHERE category = :category
    ORDER BY VECTOR_DISTANCE(embedding, :query_embedding, COSINE)
    FETCH FIRST 5 ROWS ONLY
    """
    
    results = execute_query(sql, {
        'category': diagnosis_category,
        'query_embedding': query_embedding
    })
    
    return format_evidence_context(results)
```

## 6. Security & HIPAA Compliance

### 6.1 Data Encryption
- **At Rest**: Oracle Database Transparent Data Encryption (TDE)
- **In Transit**: TLS 1.3 for all connections
- **Application**: AES-256 encryption for sensitive fields

### 6.2 Access Controls

```python
# Role-Based Access Control (RBAC)
class AccessControl:
    @staticmethod
    def check_patient_access(therapist_id, patient_id):
        """
        Ensure therapist can only access their own patients
        """
        query = """
        SELECT COUNT(*) as access_count
        FROM patients
        WHERE patient_id = :patient_id
        AND therapist_id = :therapist_id
        """
        result = execute_query(query, {
            'patient_id': patient_id,
            'therapist_id': therapist_id
        })
        
        if result[0]['access_count'] == 0:
            raise PermissionError("Access denied: Patient not assigned to this therapist")
        
        # Log access for HIPAA audit trail
        log_access(therapist_id, 'VIEW', 'PATIENT', patient_id)
        
        return True
```

### 6.3 HIPAA Compliance Checklist
- ✅ Encrypted data storage (TDE)
- ✅ Encrypted data transmission (TLS)
- ✅ Access controls and authentication (JWT)
- ✅ Audit logging (all access tracked)
- ✅ Data isolation (therapist-level separation)
- ✅ Secure password storage (bcrypt/Argon2)
- ✅ Session timeout (automatic logout)
- ✅ No data sharing with LLM training

## 7. Development Workflow

### 7.1 Local Development (Mac)
```bash
# VS Code setup
# 1. Clone repository
git clone https://github.com/davidastart/sample_app.git
cd sample_app

# 2. Create feature branch
git checkout -b feature/treatment-plan-ui

# 3. Develop and test locally
npm run dev  # Frontend
python app.py  # Backend

# 4. Commit changes
git add .
git commit -m "Add treatment plan generation UI"

# 5. Push to GitHub using GitHub Desktop
# (Visual interface for push/pull operations)
```

### 7.2 Deployment Workflow
```bash
# On OCI Linux 9 VM
# 1. Pull latest from GitHub
git pull origin main

# 2. Build containers with Podman
podman build -t therapist-frontend:latest ./frontend
podman build -t therapist-backend:latest ./backend

# 3. Pull Oracle Database 23ai
podman pull container-registry.oracle.com/database/free:latest

# 4. Create pod network
podman network create therapist-app-network

# 5. Start containers
podman run -d \
  --name oracle-db \
  --network therapist-app-network \
  -p 1521:1521 \
  -e ORACLE_PWD=<secure_password> \
  -v oracle-data:/opt/oracle/oradata \
  container-registry.oracle.com/database/free:latest

podman run -d \
  --name backend \
  --network therapist-app-network \
  -p 8000:8000 \
  -e DATABASE_URL=oracle://oracle-db:1521/FREEPDB1 \
  -e OCI_CONFIG_FILE=/app/oci_config.json \
  therapist-backend:latest

podman run -d \
  --name frontend \
  --network therapist-app-network \
  -p 3000:3000 \
  -e BACKEND_URL=http://backend:8000 \
  therapist-frontend:latest
```

## 8. Implementation Phases

### Phase 1: Foundation (Weeks 1-2)
- [ ] Set up OCI Linux 9 VM
- [ ] Install Podman
- [ ] Deploy Oracle Database 23ai container
- [ ] Create database schema
- [ ] Set up GitHub repository structure
- [ ] Configure OCI Generative AI access

### Phase 2: Backend Development (Weeks 3-5)
- [ ] User authentication system (JWT)
- [ ] Therapist account management API
- [ ] Patient management API (CRUD with access controls)
- [ ] Session notes API
- [ ] Treatment plan generation API
- [ ] OCI Generative AI integration
- [ ] RAG implementation with vector search

### Phase 3: Frontend Development (Weeks 6-8)
- [ ] Login/authentication UI
- [ ] Therapist dashboard
- [ ] Patient list and profile views
- [ ] Session entry forms
- [ ] Treatment plan viewer/editor
- [ ] Office template management UI

### Phase 4: Evidence Base Integration (Weeks 9-10)
- [ ] Load DSM-5-TR diagnostic criteria (structured data)
- [ ] Import evidence-based treatment guidelines
- [ ] Create office-wide treatment templates
- [ ] Generate and store vector embeddings
- [ ] Test RAG retrieval quality

### Phase 5: Testing & Security (Weeks 11-12)
- [ ] Security audit
- [ ] HIPAA compliance review
- [ ] Penetration testing
- [ ] User acceptance testing
- [ ] Performance optimization

### Phase 6: Deployment & Training (Week 13)
- [ ] Production deployment
- [ ] User training materials
- [ ] Documentation
- [ ] Monitoring setup
- [ ] Backup procedures

## 9. Technology Stack

### Frontend
- **Framework**: Next.js 14 (React)
- **UI Library**: Tailwind CSS + shadcn/ui
- **State Management**: React Context + TanStack Query
- **Forms**: React Hook Form + Zod validation
- **Authentication**: JWT with httpOnly cookies

### Backend
- **Framework**: FastAPI (Python) or Express.js (Node.js)
- **ORM**: SQLAlchemy (Python) or Knex.js (Node.js)
- **Authentication**: JWT with refresh tokens
- **API Documentation**: OpenAPI/Swagger
- **OCI SDK**: Oracle Cloud Infrastructure Python SDK

### Database
- **Database**: Oracle Database 23ai Free (container)
- **Features Used**:
  - Vector Search (VECTOR data type)
  - JSON support
  - Full-text search
  - Transparent Data Encryption

### Infrastructure
- **Container Runtime**: Podman
- **Operating System**: Oracle Linux 9
- **Cloud Provider**: Oracle Cloud Infrastructure (OCI)
- **AI Service**: OCI Generative AI (Cohere Command A)

## 10. Evidence-Based Resources

### Clinical Guidelines Sources
1. **DSM-5-TR** (Diagnostic and Statistical Manual of Mental Disorders, 5th Edition, Text Revision)
   - Official diagnostic criteria
   - Updated diagnostic codes
   - Cultural considerations

2. **APA Practice Guidelines**
   - Evidence-based treatment recommendations
   - Practice parameters for specific disorders

3. **NICE Guidelines** (National Institute for Health and Care Excellence)
   - Evidence-based clinical practice guidelines
   - Treatment algorithms

4. **Cochrane Reviews**
   - Systematic reviews of treatment efficacy
   - Meta-analyses of interventions

5. **Society of Clinical Psychology (Division 12)**
   - Research-supported psychological treatments
   - Treatment efficacy ratings

6. **SAMHSA** (Substance Abuse and Mental Health Services Administration)
   - Evidence-based practices for substance use disorders
   - Trauma-informed care guidelines

### Academic Databases for RAG
- PubMed/MEDLINE (mental health research)
- PsycINFO (psychology and behavioral sciences)
- Google Scholar (broad academic search)

## 11. Data Privacy Guarantee

### OCI Generative AI Privacy Features:
1. **No Training on Customer Data**: OCI does not use customer data to train or improve foundation models
2. **Data Residency**: All data stays within your OCI tenancy
3. **Isolation**: Each customer's data is isolated
4. **No Cross-Contamination**: Patient data never leaves your secure environment
5. **Audit Trail**: Complete logging of all AI interactions

### Implementation:
```python
# Privacy configuration in API calls
def generate_with_privacy(prompt, patient_data):
    """
    All data processing happens within your OCI tenancy.
    Oracle does NOT use this data for model training.
    """
    response = generative_ai_client.generate_text(
        compartment_id=COMPARTMENT_ID,  # Your isolated environment
        model_id="cohere.command-a-03-2025",
        prompt=prompt,
        # No telemetry or training data collection
        is_stream=False
    )
    
    # Log for HIPAA compliance
    log_ai_interaction(
        therapist_id=current_user.id,
        patient_id=patient_data['id'],
        prompt_hash=hash(prompt),  # Don't store actual prompt
        timestamp=datetime.now()
    )
    
    return response
```

## 12. Cost Estimation

### OCI Resources (Monthly)
- **Compute VM** (VM.Standard.E4.Flex, 2 OCPUs, 16GB RAM): ~$50-70/month
- **Block Storage** (100GB): ~$5/month
- **OCI Generative AI** (Pay-per-use): 
  - On-demand pricing: ~$0.015 per 1K input tokens, ~$0.075 per 1K output tokens
  - Estimated: $50-100/month for moderate usage (50-100 treatment plans/month)
- **Database**: Oracle Database 23ai Free (included)

**Total Estimated Monthly Cost**: ~$105-175/month

### Scaling Considerations
- Start with on-demand OCI Generative AI
- Can move to dedicated AI cluster for higher volume (contact Oracle for pricing)
- Database can scale to Oracle Database Enterprise Edition as practice grows

## 13. Next Steps

1. **Immediate**:
   - Set up OCI account and VM
   - Install Podman and pull Oracle Database 23ai
   - Initialize GitHub repository
   - Set up local development environment

2. **Week 1**:
   - Create database schema
   - Set up OCI Generative AI access
   - Build authentication system

3. **Week 2**:
   - Develop core APIs (patients, sessions)
   - Create basic frontend shell
   - Test database connections

4. **Ongoing**:
   - Follow phased implementation plan
   - Regular security reviews
   - Iterative user testing

## 14. Support & Resources

### Documentation Links
- [OCI Generative AI Documentation](https://docs.oracle.com/iaas/Content/generative-ai/home.htm)
- [Oracle Database 23ai Documentation](https://docs.oracle.com/en/database/oracle/oracle-database/23/)
- [Cohere on OCI](https://docs.cohere.com/v2/docs/oracle-cloud-infrastructure-oci)
- [Podman Documentation](https://docs.podman.io/)
- [DSM-5-TR Updates](https://www.psychiatry.org/psychiatrists/practice/dsm)

### Contact Points
- OCI Support: Available through OCI Console
- Oracle Community: [Oracle Cloud Customer Connect](https://cloudcustomerconnect.oracle.com/)
- GitHub Issues: For bug reports and feature requests

---

**Document Version**: 1.0  
**Last Updated**: October 25, 2025  
**Author**: Development Team  
**Status**: Planning Phase
