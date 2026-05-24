INTERFACE zifi_ca_stat_transition
  PUBLIC.

  "--------------------------------------------------------------------
  " Z-Status Framework — BAdI Interface ZIFI_CA_STAT_TRANSITION
  "
  " Enhancement spot : ESPOT_ZCASTAT
  " BAdI definition  : BADI_ZCASTAT_TRANSITION
  " Filter           : STATUS_TYPE  TYPE ZDE_CA_STAT_TYPE  (CHAR 40)
  "                    MUST be declared with ZDE_CA_STAT_TYPE in SE19.
  " Multiple use     : Yes
  " Default impl.    : No (no-op when no implementation active)
  "--------------------------------------------------------------------

  "& ① Before log write — raise ZCX_CA_STATUS_ERROR to block.
  METHODS validate_transition
    IMPORTING
      iv_status_type TYPE zde_ca_stat_type
      iv_object_key  TYPE zde_ca_stat_obj_key
      iv_from_status TYPE zde_ca_stat_code
      iv_to_status   TYPE zde_ca_stat_code
    RAISING
      zcx_ca_status_error.

  "& ② After log write — fire-and-inform. Exceptions are caught by
  "&   framework and logged. iv_log_uuid references the exact log entry.
  METHODS after_transition
    IMPORTING
      iv_status_type TYPE zde_ca_stat_type
      iv_object_key  TYPE zde_ca_stat_obj_key
      iv_from_status TYPE zde_ca_stat_code
      iv_to_status   TYPE zde_ca_stat_code
      iv_log_uuid    TYPE sysuuid_16.

ENDINTERFACE.
