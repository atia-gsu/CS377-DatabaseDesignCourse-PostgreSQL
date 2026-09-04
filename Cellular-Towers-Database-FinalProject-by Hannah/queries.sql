SELECT
    c.call_id,
    c.caller_device_id,
    c.receiver_device_id,
    t.tower_name,
    r.municipality,
    r.county,
    c.start_time,
    c.end_time
FROM calls c
JOIN towers t ON c.tower_id = t.tower_id
JOIN regions r ON t.region_id = r.region_id
WHERE c.caller_device_id <> c.receiver_device_id
ORDER BY r.county, r.municipality, c.start_time;
