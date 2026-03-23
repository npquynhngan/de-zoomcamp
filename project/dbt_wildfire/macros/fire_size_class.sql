{% macro size_class_label(column_name) %}
    case {{ column_name }}
        when 'A' then '0 - 0.25 acres'
        when 'B' then '0.26 - 9.9 acres'
        when 'C' then '10 - 99.9 acres'
        when 'D' then '100 - 299 acres'
        when 'E' then '300 - 999 acres'
        when 'F' then '1,000 - 4,999 acres'
        when 'G' then '5,000+ acres'
        else 'Unknown'
    end
{% endmacro %}
