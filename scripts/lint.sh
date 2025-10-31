#!/bin/bash
set -e

# Linting script for nimsync
# Usage: ./scripts/lint.sh [check|fix]

MODE=${1:-check}

echo "🔍 Running nimsync linting in $MODE mode..."

# Find all Nim source files
NIM_FILES=$(find src tests -name "*.nim" -type f)

case $MODE in
  "check")
    echo "📋 Checking code formatting and style..."

    # Check if nimpretty is available
    if command -v nimpretty &> /dev/null; then
      echo "Checking formatting with nimpretty..."
      for file in $NIM_FILES; do
        echo "Checking $file..."
        nimpretty --check "$file" || echo "❌ $file needs formatting"
      done
    else
      echo "⚠️  nimpretty not found, skipping format checks"
    fi

    # Static analysis with nim check
    echo "Running static analysis..."
    for file in $NIM_FILES; do
      if [[ $file == src/* ]]; then
        echo "Checking $file..."
        nim check --hints:off "$file" || echo "❌ $file has issues"
      fi
    done

    # Additional style checks
    echo "Checking coding standards..."

    # Check for trailing whitespace
    echo "Checking for trailing whitespace..."
    if grep -r -n "[[:space:]]$" src/ tests/ 2>/dev/null; then
      echo "❌ Found trailing whitespace (lines above)"
    else
      echo "✅ No trailing whitespace found"
    fi

    # Check for tabs (should use spaces)
    echo "Checking for tabs..."
    if grep -r -n $'\t' src/ tests/ 2>/dev/null; then
      echo "❌ Found tab characters (lines above)"
    else
      echo "✅ No tab characters found"
    fi

    # Check for TODO/FIXME comments
    echo "Checking for TODO/FIXME comments..."
    if grep -r -n -i -E "(TODO|FIXME|XXX|HACK)" src/ tests/ 2>/dev/null; then
      echo "📝 Found TODO/FIXME comments (review above)"
    else
      echo "✅ No TODO/FIXME comments found"
    fi

    # Check for long lines (>100 characters)
    echo "Checking for long lines (>100 chars)..."
    if grep -r -n ".\{101,\}" src/ tests/ 2>/dev/null; then
      echo "📏 Found long lines (review above)"
    else
      echo "✅ No overly long lines found"
    fi

    echo "🔍 Lint checking completed"
    ;;

  "fix")
    echo "🔧 Fixing code formatting..."

    if command -v nimpretty &> /dev/null; then
      for file in $NIM_FILES; do
        echo "Formatting $file..."
        nimpretty "$file"
      done
      echo "✅ Code formatting applied"
    else
      echo "❌ nimpretty not found, cannot auto-fix formatting"
      exit 1
    fi

    # Remove trailing whitespace
    echo "Removing trailing whitespace..."
    for file in $NIM_FILES; do
      sed -i 's/[[:space:]]*$//' "$file"
    done

    echo "🔧 Auto-fixes applied"
    ;;

  *)
    echo "❌ Unknown mode: $MODE"
    echo "Usage: $0 [check|fix]"
    exit 1
    ;;
esac

echo "✨ Linting completed!"