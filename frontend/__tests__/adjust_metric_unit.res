open Jest
open AdjustMetricUnit

describe("Expect", () => {
  open Expect

  describe("Test formatSize when no change", () => {
    test("1 unit", () => expect(formatSize(1., "unit")) |> toEqual((1., "unit")))

    test("1 mb", () => expect(formatSize(1., "mbps")) |> toEqual((1., "mbps")))
    test("12 mb", () => expect(formatSize(12., "mbps")) |> toEqual((12., "mbps")))
    test("120 mb", () => expect(formatSize(120., "mbps")) |> toEqual((120., "mbps")))
    test("1 mB", () => expect(formatSize(1., "mBps")) |> toEqual((1., "mBps")))
    test("1 MB", () => expect(formatSize(1., "MBps")) |> toEqual((1., "MBps")))
  })

  describe("Test formatSize when converting to lower units", () => {
    test("0.001 mb", () => expect(formatSize(0.001, "mbps")) |> toEqual((1., "kbps")))
    test("0.001 kb", () => expect(formatSize(0.001, "kbps")) |> toEqual((0.001, "kbps")))
    test("0.0013 kb", () => expect(formatSize(0.0013, "kbps")) |> toEqual((0.0013, "kbps")))
    test("0.00134 kb", () => expect(formatSize(0.00134, "kbps")) |> toEqual((0.0013, "kbps")))
    test("0.0000013 mb", () => expect(formatSize(0.0000013, "mbps")) |> toEqual((0.0013, "kbps")))
    test("0.000000013 mb", () => expect(formatSize(0.000000013, "mbps")) |> toEqual((0.000013, "kbps")))
    test("0.0000000134 mb", () => expect(formatSize(0.0000000134, "mbps")) |> toEqual((0.000013, "kbps")))
  })

  describe("Test formatSize when converting to higher units", () => {
    test("1200 mb", () => expect(formatSize(1200., "mbps")) |> toEqual((1.2, "gbps")))
    test("1200000 mb", () => expect(formatSize(1200000., "mbps")) |> toEqual((1.2, "tbps")))
    test("1200000.123 zb", () => expect(formatSize(1200000.123, "zbps")) |> toEqual((1200., "ybps")))
  })

})
