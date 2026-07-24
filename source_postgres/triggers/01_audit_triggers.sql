-- Attach the audit trigger to all critical tables, passing the primary-key column name.
CREATE TRIGGER audit_studies
AFTER INSERT OR UPDATE OR DELETE ON az_clinical.studies
FOR EACH ROW EXECUTE FUNCTION az_clinical.audit_trigger('study_id');

CREATE TRIGGER audit_trial_sites
AFTER INSERT OR UPDATE OR DELETE ON az_clinical.trial_sites
FOR EACH ROW EXECUTE FUNCTION az_clinical.audit_trigger('site_id');

CREATE TRIGGER audit_patients
AFTER INSERT OR UPDATE OR DELETE ON az_clinical.patients
FOR EACH ROW EXECUTE FUNCTION az_clinical.audit_trigger('patient_id');

CREATE TRIGGER audit_demographics
AFTER INSERT OR UPDATE OR DELETE ON az_clinical.demographics
FOR EACH ROW EXECUTE FUNCTION az_clinical.audit_trigger('demographic_id');

CREATE TRIGGER audit_visits
AFTER INSERT OR UPDATE OR DELETE ON az_clinical.visits
FOR EACH ROW EXECUTE FUNCTION az_clinical.audit_trigger('visit_id');

CREATE TRIGGER audit_vital_signs
AFTER INSERT OR UPDATE OR DELETE ON az_clinical.vital_signs
FOR EACH ROW EXECUTE FUNCTION az_clinical.audit_trigger('vital_sign_id');

CREATE TRIGGER audit_lab_results
AFTER INSERT OR UPDATE OR DELETE ON az_clinical.lab_results
FOR EACH ROW EXECUTE FUNCTION az_clinical.audit_trigger('result_id');

CREATE TRIGGER audit_adverse_events
AFTER INSERT OR UPDATE OR DELETE ON az_clinical.adverse_events
FOR EACH ROW EXECUTE FUNCTION az_clinical.audit_trigger('ae_id');

CREATE TRIGGER audit_concomitant_medications
AFTER INSERT OR UPDATE OR DELETE ON az_clinical.concomitant_medications
FOR EACH ROW EXECUTE FUNCTION az_clinical.audit_trigger('cm_id');

CREATE TRIGGER audit_randomization
AFTER INSERT OR UPDATE OR DELETE ON az_clinical.randomization
FOR EACH ROW EXECUTE FUNCTION az_clinical.audit_trigger('randomization_id');

CREATE TRIGGER audit_crf_data
AFTER INSERT OR UPDATE OR DELETE ON az_clinical.crf_data
FOR EACH ROW EXECUTE FUNCTION az_clinical.audit_trigger('crf_data_id');
