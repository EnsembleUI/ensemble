from jinja2 import Template


def render_template(file_path, **kwargs):
    with open(file_path, "r") as file:
        template_content = file.read()

    # Create a Jinja template object
    template = Template(template_content)

    # Render the template with the provided variables
    result = template.render(**kwargs)

    with open(file_path, "w") as file:
        file.write(result)
