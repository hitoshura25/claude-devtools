# Release Notes for Play Store

## Overview

This directory contains release notes (what's new) for different locales. These notes are displayed to users when they update your app.

## Directory Structure

Each locale has its own directory with a `whatsnew` file:

```
distribution/whatsnew/
├── en-US/
│   └── whatsnew
├── de-DE/
│   └── whatsnew
├── es-ES/
│   └── whatsnew
├── fr-FR/
│   └── whatsnew
└── ...
```

## File Format

- **Filename:** `whatsnew` (no file extension)
- **Format:** Plain text (UTF-8 encoding)
- **Max length:** 500 characters
- **Line breaks:** Supported but count toward character limit

## Content Guidelines

### What to Include
- New features and improvements
- Bug fixes (if significant to users)
- Performance enhancements
- UI/UX changes
- Security updates (if user-facing)

### What NOT to Include
- Internal code changes
- Developer-only features
- "Bug fixes and improvements" (too vague)
- Marketing speak or promotional content
- Future features (only released features)

### Writing Style
- ✅ Use bullet points for clarity
- ✅ Start with most important changes
- ✅ Use active voice ("Added", "Fixed", "Improved")
- ✅ Be specific and concise
- ✅ Use user-friendly language
- ❌ Avoid technical jargon
- ❌ Don't use ALL CAPS
- ❌ Don't use excessive punctuation!!!

## Examples

### Good Example (186 characters)
```
- New: Dark mode support throughout the app
- Improved: 50% faster app startup time
- Fixed: Crash when uploading large photos
- Updated: Refreshed settings screen design
```

### Bad Example (Too vague)
```
- Bug fixes and performance improvements
- Various updates
- Made the app better
```

### Bad Example (Too technical)
```
- Refactored UserRepository to use Kotlin Flow
- Migrated from RxJava to Coroutines
- Updated Gradle dependencies to latest versions
```

## Supported Locales

Common Play Store locales:

| Locale | Language | Region |
|--------|----------|--------|
| en-US | English | United States |
| en-GB | English | United Kingdom |
| de-DE | German | Germany |
| es-ES | Spanish | Spain |
| fr-FR | French | France |
| it-IT | Italian | Italy |
| ja-JP | Japanese | Japan |
| ko-KR | Korean | South Korea |
| pt-BR | Portuguese | Brazil |
| ru-RU | Russian | Russia |
| zh-CN | Chinese | Simplified |
| zh-TW | Chinese | Traditional |
| ar | Arabic | - |
| hi-IN | Hindi | India |
| id | Indonesian | - |

For complete list, see: https://support.google.com/googleplay/android-developer/answer/9844778

## Updating Release Notes

### For Each Release

1. Create release notes in primary language (usually en-US)
2. Keep under 500 characters
3. Translate for other supported locales
4. Test that notes display correctly in Play Console
5. Commit changes before building release

### Translation Tips

- Use professional translation service for accuracy
- Native speakers review for cultural appropriateness
- Keep formatting consistent across locales
- Test character limits in each language (some translate longer)

### Automation

Release notes are automatically included in GitHub Actions deployment:

```yaml
# In .github/workflows/playstore-deploy.yml
- name: Deploy to Play Store
  uses: r0adkll/upload-google-play@v1
  with:
    whatsNewDirectory: distribution/whatsnew
```

## Character Count Checker

To check character count:

```bash
# Count characters in en-US release notes
wc -m distribution/whatsnew/en-US/whatsnew
```

Or use online tool: https://www.charactercountonline.com/

## Testing

Before deploying, verify:

1. File exists for each supported locale
2. Files are plain text (UTF-8)
3. Character count < 500 for each file
4. Content is user-friendly and clear
5. No typos or grammatical errors

## Troubleshooting

**"Release notes not showing in Play Console"**
- Check file name is exactly `whatsnew` (no extension)
- Verify UTF-8 encoding
- Ensure file is not empty
- Check locale code matches Play Console format

**"Character limit exceeded"**
- Remove unnecessary words
- Use abbreviations carefully
- Split across multiple short bullets
- Remove marketing fluff

**"Notes show differently on device"**
- Play Store may truncate if too long
- Test on actual device
- Keep most important info at the top

## Version-Specific Notes

If you need different notes for different versions:

```
distribution/whatsnew-v1.2.0/
  en-US/
    whatsnew
distribution/whatsnew-v1.3.0/
  en-US/
    whatsnew
```

Then specify in GitHub Actions workflow.

## References

- [Release Notes Guidelines](https://support.google.com/googleplay/android-developer/answer/7159011)
- [Localization Best Practices](https://developer.android.com/distribute/best-practices/launch/localization-checklist)
- [Play Console Help](https://support.google.com/googleplay/android-developer)
