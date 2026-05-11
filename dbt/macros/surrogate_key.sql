{% macro surrogate_key(fields) -%}
    sha2(concat_ws('|', {%- for field in fields -%} coalesce(cast({{ field }} as string), '') {%- if not loop.last -%}, {%- endif -%}{%- endfor -%}), 256)
{%- endmacro %}
