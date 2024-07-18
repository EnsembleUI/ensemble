import argparse
from jinja_utils import render_template


# Dictionary mapping module names to import and register statements
module_info_dict = {
    'HAS_CHAT': {
        'import_statement': 'import "package:ensemble_chat/ensemble_chat.dart";',
        'register_statement1': 'GetIt.I.registerSingleton<EnsembleChat>(EnsembleChatImpl());',
        'register_statement2': 'GetIt.I.registerSingleton<EnsembleChat>(const EnsembleChatStub());'
    },
    'HAS_AUTH': {
        'import_statement': 'import "package:ensemble_auth/auth_module.dart";',
        'register_statement1': 'GetIt.I.registerSingleton<AuthModule>(AuthModuleImpl());',
        'register_statement2': 'GetIt.I.registerSingleton<AuthModule>(AuthModuleStub());'
    },
    'HAS_CONTACTS': {
        'import_statement': 'import "package:ensemble_contacts/contact_manager.dart";',
        'register_statement1': 'GetIt.I.registerSingleton<ContactManager>(ContactManagerImpl());',
        'register_statement2': 'GetIt.I.registerSingleton<ContactManager>(ContactManagerStub());'
    },
    'HAS_CONNECT': {
        'import_statement': 'import "package:ensemble_connect/plaid_link/plaid_link_manager.dart";',
        'register_statement1': 'GetIt.I.registerSingleton<PlaidLinkManager>(PlaidLinkManagerImpl());',
        'register_statement2': 'GetIt.I.registerSingleton<PlaidLinkManager>(PlaidLinkManagerStub());'
    },
    'HAS_CAMERA': {
        'import_statement': 'import "package:ensemble_camera/camera_manager.dart";',
        'register_statement1': 'GetIt.I.registerSingleton<CameraManager>(CameraManagerImpl());',
        'register_statement2': 'GetIt.I.registerSingleton<CameraManager>(CameraManagerStub());'
    },
    'HAS_FILE_MANAGER': {
        'import_statement': 'import "package:ensemble_file_manager/file_manager.dart";',
        'register_statement1': 'GetIt.I.registerSingleton<FileManager>(FileManagerImpl());',
        'register_statement2': 'GetIt.I.registerSingleton<FileManager>(FileManagerStub());'
    },
    'HAS_LOCATION': {
        'import_statement': 'import "package:ensemble_location/location_module.dart";',
        'register_statement1': 'GetIt.I.registerSingleton<LocationModule>(LocationModuleImpl());',
        'register_statement2': 'GetIt.I.registerSingleton<LocationModule>(LocationModuleStub());'
    },
    'HAS_DEEPLINK': {
        'import_statement': 'import "package:ensemble_deeplink/deferred_link_manager.dart";',
        'register_statement1': 'GetIt.I.registerSingleton<DeferredLinkManager>(DeferredLinkManagerImpl());',
        'register_statement2': 'GetIt.I.registerSingleton<DeferredLinkManager>(DeferredLinkManagerStub());'
    },
    # Add more modules as needed
}


def parse_args():
    parser = argparse.ArgumentParser(
        description='Modify ensemble_modules.dart based on module parameters.'
    )

    for module_name, _ in module_info_dict.items():
        # Convert to lowercase and replace underscores with hyphens
        arg_name = module_name.lower().replace('_', '-')
        parser.add_argument(
            f'--{arg_name}',
            type=str,
            default='false',
        )

    return parser.parse_args()


def main():
    args = parse_args()

    import_statements = []
    register_statements = []

    # Check and modify ensemble_modules.dart based on command-line arguments
    for module_name, module_info in module_info_dict.items():
        arg_name = module_name.lower()
        has_attribute = getattr(args, arg_name).lower() == 'true'

        if has_attribute:
            import_statements.append(module_info['import_statement'])
            register_statements.append(module_info[f'register_statement1'])
        else:
            register_statements.append(module_info[f'register_statement2'])

    render_template(
        "starter/lib/generated/ensemble_modules.dart",
        import_statements=import_statements,
        register_statements=register_statements
    )


if __name__ == "__main__":
    main()
