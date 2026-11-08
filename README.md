# Pocket Expenses

A small Android friendly expense tracker built with Flutter. Expenses and account movements are stored on the device in SQLite. The currency is Philippine pesos (₱). Accounts start at zero; enter each real starting balance as an adjustment before using the balance totals.

## Run the app

Install the Flutter SDK and Android Studio (including an Android SDK/emulator), open this project folder, and from the project terminal run:

```sh
flutter pub get
flutter run
```

On an Android device, enable USB debugging and select it with `flutter devices`. To run the tests, use `flutter test`; to make a local release-mode APK, use `flutter build apk --release`.

### Build and release APKs on GitHub

The **Android build** workflow runs manually and creates a draft GitHub Release with signed, split APKs attached directly as separate assets. Before running it, create an upload keystore and add these repository Actions secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, and `ANDROID_STORE_PASSWORD`. Encode the keystore file as one line of Base64 for `ANDROID_KEYSTORE_BASE64`. In **Actions → Android build → Run workflow**, enter a release tag such as `v0.1.0`. When the workflow completes, open **Releases → Drafts**, review the generated release and APK assets, then publish it. Keep the keystore and passwords backed up privately.

## Accounts and imports

The app starts with Cash on Hand, GCash, and Savings Account. Use **Add income** beside **Add expense** to record money received into an account. On **Accounts**, add other money accounts, enter or correct a starting balance with **Adjust balance → Add money**, record cash withdrawals with **Take out**, and move funds with **Transfer**. Income and adjustments appear separately in the movement history. Transfers update both accounts without changing the combined balance. New and edited expenses include a **Paid from** account.

On **History**, choose **Import** to load an `.xlsx` expense sheet or **Export** to save the app's records as an `.xlsx` spreadsheet. The importer recognizes common headings (date, amount, category, paid from/account, and note/purpose/description), and the organized Finance workbook's Transactions sheet. Exports include an **Accounts** sheet with each account's current balance as well as expense records. Import matches accounts by name, creates accounts that are missing on the device, and synchronizes their balances to the workbook snapshot; importing that same snapshot again does not add the balance twice. Exported expense rows retain their account name and unique import key, so importing the same export again does not duplicate them. The app asks you to choose an account for expense rows whose account is missing or unknown. Historical rows with a blank date or amount are retained and can be completed by editing them. Invalid amounts and fully blank rows are skipped. New expenses still require an amount greater than zero.

Account removal is blocked when the account is referenced by an expense, transfer, or balance adjustment. The app explains why and will not delete it. The **Undo latest** action has been removed so recorded movements cannot be silently reversed.

### Analytics and appearance

The **Analytics** tab summarizes income, expenses, net cash flow, and savings rate for the current week, month, quarter, year, or a custom date range. Each period is compared with the immediately preceding period of equal length. The home screen gives the same monthly metrics in a compact two-column grid; tapping a tile opens Analytics. Account and expense-category filters can be combined.

Analytics reuses expense records and account movements. Only movements explicitly recorded as `income` count as income; transfers and balance adjustments are excluded. Net cash flow is income minus recorded expenses, and savings rate is net cash flow divided by income (shown as unavailable when income is zero). The current expense model does not represent refunds, merchants, or payment methods, and the app does not yet track recurring items, budgets, or savings goals; Analytics does not infer those values from notes. Income is grouped by the account receiving it. Average daily spending divides the selected-period expense total by every calendar day in the selected range.

Use the appearance menu in the top bar to follow the system setting or choose light or dark mode. The selection is saved on the device. Material 3 color schemes use Android dynamic colors when available and a seeded palette elsewhere.

### Android release signing

The project can build a release-mode APK locally. Without a private upload key, Gradle uses the debug key so that release-mode testing remains possible; this APK cannot be published to Google Play. Before publishing, create an upload key, put its properties in the ignored file `android/key.properties`, and keep the key and passwords private. The release build is configured to use that key when the file exists. Also replace the current example application ID in `android/app/build.gradle.kts` with an ID you control before the first store release; changing it after publishing creates a different app.

## Structure

- `lib/app`: app entry screen, navigation, persisted appearance preference, and Material 3 themes.
- `lib/core/data`: SQLite database setup.
- `lib/features/analytics`: analytics range and calculation logic, responsive charts, filters, and insights.
- `lib/features/accounts`: account balances, transfers, adjustments, and account screens.
- `lib/features/dashboard`: monthly overview and analytics summary tiles.
- `lib/features/expenses/domain`: expense/category models, repository contract, and pure analytics/filter logic.
- `lib/features/expenses/data`: SQLite repository implementation and spreadsheet importer/exporter.
- `lib/features/expenses/presentation`: expense history, spreadsheet actions, add/edit form, and `ChangeNotifier` controller.
- `lib/shared/widgets`: reusable money and empty state widgets.
- `test`: tests for totals, filters, account balances, and spreadsheet round trips.

## Dependencies

- `sqflite` and `path`: persist structured expenses in SQLite and safely construct the database path.
- `dynamic_color`: use Android system dynamic colors where supported, with a seeded Material 3 fallback.
- `file_picker`: open the phone's native file picker to select the workbook.
- `excel`: read the workbook locally without uploading it.
- `flutter_lints`: standard Flutter static analysis rules.
- State management uses Flutter's built in `ChangeNotifier`, so no state package is needed.
- Database version 7 expands the allowed account movement types to include income and stores the appearance preference. Migrations preserve existing movements, expenses, IDs, and notes.

## Extend it

To add a feature, create its `domain`, `data`, and `presentation` folders under `lib/features/<feature>` and share only common UI in `lib/shared`. Keep persistence behind `ExpenseRepository`; a different backend can implement that contract and be passed into `ExpenseController` from `main.dart` without changing the screens. When adding category values, the enum automatically feeds the form and filter; add a migration if the storage schema itself changes.
