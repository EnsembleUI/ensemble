# Package Migration Strategy: Modules to Packages

## Overview

This document outlines the strategic migration of specific packages from the `modules/` directory to the `packages/` directory within the Ensemble monorepo. This migration is designed to maintain backward compatibility while enabling modern package management and publication workflows.

## Why This Migration Was Necessary

### 1. **Dependency Resolution Conflicts**

- **Problem**: The `modules/` directory contains packages that are tightly coupled with the Ensemble runtime, making them difficult to use as standalone dependencies in other projects.
- **Solution**: Moving packages to the `packages/` directory allows them to be published to pub.dev and used independently.

### 2. **Package Publication Requirements**

- **Problem**: Packages in `modules/` cannot be easily published to pub.dev due to their tight integration with the Ensemble ecosystem i.e used as git with main ref. This causes conflicts when we update them or publish to pub.dev.
- **Solution**: The `packages/` directory provides a clean separation for packages intended for public distribution.

### 3. **Backward Compatibility**

- **Problem**: Existing Ensemble applications depend on packages from the `modules/` directory.
- **Solution**: Keep both versions temporarily to ensure smooth transitions for existing users.

## Migrated Packages

The following packages have been migrated from `modules/` to `packages/`:

### 1. **parsejs_null_safety** (formerly `jsparser`)

- **Old Location**: `modules/parsejs_null_safety/`
- **New Location**: `packages/parsejs_null_safety/`
- **Purpose**: JavaScript parser with null safety support
- **Status**: ✅ Published to pub.dev

### 2. **ensemble_otp** (formerly `otp_pin_field`)

- **Old Location**: `modules/otp_pin_field/`
- **New Location**: `packages/ensemble_otp/`
- **Purpose**: OTP/PIN field widget for Flutter
- **Status**: ✅ Published for pub.dev

### 3. **ensemble_ts_interpreter**

- **Old Location**: `modules/ensemble_ts_interpreter/`
- **New Location**: `packages/ensemble_ts_interpreter/`
- **Purpose**: JavaScript (ES5) interpreter written in Dart
- **Status**: ✅ Published for pub.dev

### 4. **ensemble_device_preview** (formerly `device_preview`)

- **Old Location**: `modules/device_preview/`
- **New Location**: `packages/ensemble_device_preview/`
- **Purpose**: Device preview and testing utilities
- **Status**: ✅ Published for pub.dev

## Current State

### **Dual Package Strategy**

- **`modules/` versions**: Kept for backward compatibility with older Ensemble runtime versions
- **`packages/` versions**: New, actively maintained versions intended for pub.dev publication

### **Melos Configuration**

The `melos.yaml` has been updated to exclude deprecated packages from the workspace:

```yaml
packages:
  - modules/**
  - starter
  - packages/**

ignore:
  - modules/ensemble_ts_interpreter
```

## What This Means for Developers

### **For New Projects**

- Use latest ensemble version (ensemble: ^1.2.0)

### **For Existing Projects**

- Move to latest ensemble version as soon as possible (ensemble: ^1.2.0)

### **For Package Maintainers**

- Focus development efforts on `packages/` versions
- `modules/` versions are deprecated and will not receive updates
- Use `packages/` versions for testing and development

## Benefits of This Approach

### **Immediate Benefits**

- ✅ Enables pub.dev publication
- ✅ Maintains backward compatibility
- ✅ Allows independent package development
- ✅ Allows us to properly update individual packages without affecting the whole ensemble runtime

### **Long-term Benefits**

- 🚀 Better package ecosystem management
- 🚀 Independent versioning and release cycles
- 🚀 Easier integration with other Flutter projects
- 🚀 Improved dependency resolution
- 🚀 Better separation of concerns
- 🚀 Better testing and CI/CD pipelines
- 🚀 Better package management and versioning
- 🚀 Easier to update packages without affecting the whole ensemble runtime

## Conclusion

This migration strategy provides a balanced approach to modernizing the Ensemble package ecosystem while maintaining backward compatibility.

---

**Last Updated**: Aug 15 2025
