import { describe, expect, it } from "vitest";

import { getAllowedSignupDomains, isEmailDomainAllowed } from "./isEmailDomainAllowed";

describe("getAllowedSignupDomains", () => {
  it("returns an empty list when the variable is unset or blank", () => {
    expect(getAllowedSignupDomains(undefined)).toEqual([]);
    expect(getAllowedSignupDomains("")).toEqual([]);
    expect(getAllowedSignupDomains(" , ")).toEqual([]);
  });

  it("normalises whitespace, case and leading @", () => {
    expect(getAllowedSignupDomains(" Example.com, @other.org ,third.io")).toEqual([
      "example.com",
      "other.org",
      "third.io",
    ]);
  });
});

describe("isEmailDomainAllowed", () => {
  const allowed = ["scaientist.eu", "scaientist.com", "sci.tools"];

  it("allows everything when no domains are configured", () => {
    expect(isEmailDomainAllowed("anyone@gmail.com", [])).toBe(true);
  });

  it("allows configured domains, case-insensitively", () => {
    expect(isEmailDomainAllowed("luka@scaientist.eu", allowed)).toBe(true);
    expect(isEmailDomainAllowed("LR@SCAIENTIST.COM", allowed)).toBe(true);
    expect(isEmailDomainAllowed("x@sci.tools", allowed)).toBe(true);
  });

  it("rejects other domains, subdomains and malformed addresses", () => {
    expect(isEmailDomainAllowed("someone@gmail.com", allowed)).toBe(false);
    expect(isEmailDomainAllowed("someone@evil.scaientist.eu", allowed)).toBe(false);
    expect(isEmailDomainAllowed("someone@scaientist.eu.attacker.com", allowed)).toBe(false);
    expect(isEmailDomainAllowed("not-an-email", allowed)).toBe(false);
  });
});
