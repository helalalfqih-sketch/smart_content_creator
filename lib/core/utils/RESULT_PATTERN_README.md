# 🎯 Result Pattern - Enterprise Error Handling

## Overview

The Result Pattern provides **type-safe error handling** across all async operations in the app (AI, Database, Network, etc.). This eliminates silent failures and provides clear, user-friendly error messages.

## ✅ What's Implemented

### Core Infrastructure
- **`Result<T>`** - Base class for operation results
- **`Success<T>`** - Represents successful operations
- **`Failure<T>`** - Represents failed operations with categorized error types
- **Specialized Failures**:
  - `NetworkFailure` - Connectivity issues
  - `AiFailure` - AI service errors
  - `DatabaseFailure` - Database errors
  - `PermissionFailure` - File/media access issues
  - `ValidationFailure` - Input validation errors
  - `TimeoutFailure` - Operation timeouts

### ChatSmartAgent Integration
Three new Result-based methods:
1. **`analyzeInputWithResult()`** - Type-safe input analysis
2. **`extractProductNameWithResult()`** - Type-safe product extraction
3. **`generateResponseWithResult()`** - Type-safe AI generation

## 📖 Quick Start

### Basic Usage

```dart
// Old way (no error handling)
final productName = await agent.extractProductName(image);
if (productName == null) {
  // What went wrong? Network? AI? Permission?
  print('Failed');
}

// New way (with Result Pattern)
final result = await agent.extractProductNameWithResult(image);

result.when(
  success: (name) {
    print('Product: $name');
    SnackbarUtils.showSuccess('تم التعرف على المنتج', name);
  },
  failure: (message, exception, type) {
    if (type == FailureType.network) {
      SnackbarUtils.showError('لا يوجد اتصال', message);
    } else {
      SnackbarUtils.showError('خطأ', message);
    }
  },
);
```

### Pattern Matching

```dart
final result = await agent.generateResponseWithResult(prompt);

// Using .when() for pattern matching
result.when(
  success: (response) => print('✅ $response'),
  failure: (msg, ex, type) => print('❌ $msg'),
);
```

### Chaining Operations

```dart
// Chain multiple operations
final result = await agent
    .extractProductNameWithResult(image)
    .then((nameResult) => nameResult.flatMap((name) async {
      return await agent.generateResponseWithResult(
        'وصف تسويقي لـ $name',
        image: image,
      );
    }));
```

### Side Effects

```dart
result
  .onSuccess((value) => print('Success: $value'))
  .onFailure((msg, ex, type) => print('Error: $msg'));
```

### Default Values

```dart
// Get value or default
final name = result.getOrElse('منتج غير معروف');

// Get value or compute default
final name = result.getOrElseCompute(() => 'افتراضي');
```

## 🎨 UI Integration

### Example: Enhanced _sendMessage

```dart
Future<void> _sendMessage() async {
  final result = await _agent.analyzeInputWithResult(
    IncomingMessage(text: _textController.text, image: _selectedImage),
  );

  result.when(
    success: (processedInput) {
      // Handle based on intent
      if (processedInput.intent == Intent.productDetected) {
        _handleProductDetection(processedInput);
      }
    },
    failure: (message, exception, type) {
      // Show user-friendly error
      switch (type) {
        case FailureType.network:
          _showRetryDialog('خطأ في الاتصال', message);
          break;
        case FailureType.ai:
          SnackbarUtils.showError('خطأ في الذكاء الاصطناعي', message);
          break;
        default:
          SnackbarUtils.showError('خطأ', message);
      }
    },
  );
}
```

## 🔄 Migration Guide

### Step 1: Keep Existing Methods
All existing methods (`analyzeInput`, `extractProductName`, etc.) remain unchanged for backward compatibility.

### Step 2: Use New Methods Gradually
Start using Result-based methods in new features or when refactoring:

```dart
// Old (still works)
final name = await agent.extractProductName(image);

// New (recommended)
final result = await agent.extractProductNameWithResult(image);
```

### Step 3: Update UI Error Handling
Replace generic error handling with specific failure types:

```dart
// Before
try {
  final response = await agent.generate(prompt);
} catch (e) {
  print('Error: $e'); // What kind of error?
}

// After
final result = await agent.generateResponseWithResult(prompt);
result.when(
  success: (response) => handleSuccess(response),
  failure: (msg, ex, type) {
    if (type == FailureType.network) {
      showRetryDialog();
    } else if (type == FailureType.timeout) {
      showTimeoutMessage();
    } else {
      showGenericError(msg);
    }
  },
);
```

## 🚀 Benefits

1. **Type Safety** - Compiler ensures you handle both success and failure
2. **Clear Errors** - Know exactly what went wrong (network, AI, permission, etc.)
3. **User-Friendly** - Show appropriate Arabic messages for each error type
4. **Retry Logic** - Easy to implement retry for recoverable errors
5. **Testable** - Easy to mock and test error scenarios
6. **Scalable** - Ready for Clean Architecture migration

## 📁 Files Created

- `lib/core/utils/result.dart` - Core Result Pattern infrastructure
- `lib/examples/result_pattern_examples.dart` - Usage examples
- `lib/examples/result_pattern_ui_integration.dart` - UI integration example

## 🔜 Next Steps

1. **Test** - Verify network/AI/timeout error scenarios
2. **Expand** - Add Result Pattern to more services (Database, TikTok, etc.)
3. **Clean Architecture** - Use Result Pattern as foundation for UseCases layer
4. **Logging** - Integrate with logging service to track failures

## 💡 Tips

- Use `.when()` for pattern matching
- Use `.onSuccess()` / `.onFailure()` for side effects
- Use `.map()` to transform success values
- Use `.flatMap()` to chain async operations
- Use `runCatchingAsync()` to wrap any async code

## 📚 Examples

See `lib/examples/` for:
- Basic usage examples
- Chaining operations
- UI integration
- Retry logic
- Batch processing
