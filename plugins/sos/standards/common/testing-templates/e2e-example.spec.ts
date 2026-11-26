/**
 * Playwright E2E Test Example
 *
 * 사용법:
 *   1. 이 파일을 e2e/ 디렉토리에 복사
 *   2. 프로젝트의 실제 URL과 셀렉터에 맞게 수정
 *   3. 실행: npx playwright test e2e/e2e-example.spec.ts
 */
import { test, expect } from "@playwright/test";

test.describe("Authentication Flow", () => {
  test("should display login page", async ({ page }) => {
    await page.goto("/login");

    await expect(page).toHaveTitle(/로그인|Login/);
    await expect(page.getByRole("heading")).toContainText(/로그인|Login/);
    await expect(page.getByLabel(/이메일|Email/)).toBeVisible();
    await expect(page.getByLabel(/비밀번호|Password/)).toBeVisible();
  });

  test("should show error for invalid credentials", async ({ page }) => {
    await page.goto("/login");

    await page.getByLabel(/이메일|Email/).fill("wrong@example.com");
    await page.getByLabel(/비밀번호|Password/).fill("wrongpassword");
    await page.getByRole("button", { name: /로그인|Login/ }).click();

    await expect(page.getByRole("alert")).toContainText(
      /인증 실패|Invalid credentials/,
    );
  });

  test("should login successfully with valid credentials", async ({ page }) => {
    await page.goto("/login");

    await page.getByLabel(/이메일|Email/).fill("test@example.com");
    await page.getByLabel(/비밀번호|Password/).fill("validpassword123");
    await page.getByRole("button", { name: /로그인|Login/ }).click();

    // Redirect to dashboard after login
    await expect(page).toHaveURL(/dashboard/);
    await expect(page.getByText(/환영|Welcome/)).toBeVisible();
  });
});

test.describe("API Health Check", () => {
  test("should return healthy status", async ({ request }) => {
    const response = await request.get("/api/health");
    expect(response.ok()).toBeTruthy();

    const body = await response.json();
    expect(body.status).toBe("healthy");
  });
});
