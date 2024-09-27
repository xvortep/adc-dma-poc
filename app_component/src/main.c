#include "xadcps.h"
#include "xaxidma.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xsysmon.h"
#include <xstatus.h>

#define SYSMON_DEVICE_ID XPAR_XSYSMON_0_BASEADDR
#define DMA_DEV_ID XPAR_AXI_DMA_0_BASEADDR
#define DDR_BASE_ADDR XPAR_AXI_DMA_0_BASEADDR

#define RX_BUFFER_BASE (0x00100000)
#define MAX_PKT_LEN 64 // bytes

int main() {
  XSysMon_Config *SYSConfigPtr;
  XSysMon SysMonInstPtr;
  XAxiDma_Config *CfgPtr;
  XAxiDma AxiDma;

  int Status;
  int reset_done;
  u8 *RxBufferPtr;
  u32 addr;

  xil_printf("start\r\n");

  SYSConfigPtr = XSysMon_LookupConfig(SYSMON_DEVICE_ID);
  if (SYSConfigPtr == NULL) {
    return XST_FAILURE;
  }

  CfgPtr = XAxiDma_LookupConfig(DMA_DEV_ID);
  if (!CfgPtr) {
    xil_printf("No config found for %d\r\n", DMA_DEV_ID);
    return XST_FAILURE;
  }
  xil_printf("lookup done\r\n");

  Status = XAxiDma_CfgInitialize(&AxiDma, CfgPtr);
  if (Status != XST_SUCCESS) {
    xil_printf("Initialization DMA failed %d\r\n", Status);
    return XST_FAILURE;
  }
  xil_printf("cfg initialized!\r\n");

  XSysMon_CfgInitialize(&SysMonInstPtr, SYSConfigPtr,
                        SYSConfigPtr->BaseAddress);

  XSysMon_SetSequencerMode(&SysMonInstPtr, XSM_SEQ_MODE_SAFE);
  XSysMon_SetAlarmEnables(&SysMonInstPtr, 0x0);
  XSysMon_SetSeqChEnables(&SysMonInstPtr, XSM_SEQ_CH_VCCAUX);
  XSysMon_SetAdcClkDivisor(&SysMonInstPtr, 4);
  XSysMon_SetSequencerMode(&SysMonInstPtr, XSM_SEQ_MODE_CONTINPASS);

  if (XSysMon_SelfTest(&SysMonInstPtr) != XST_SUCCESS) {
    xil_printf("selftest failed for sysmon\r\n");
    return XST_FAILURE;
  }

  RxBufferPtr = (u8 *)RX_BUFFER_BASE;

  addr = (u32)RX_BUFFER_BASE;

  XAxiDma_Reset(&AxiDma);

  xil_printf("wait for reset\r\n");
  while (XAxiDma_ResetIsDone(&AxiDma) != 1) {
  }
  xil_printf("reset done\r\n");

  XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
  XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);

  XSysMon_WriteReg(SysMonInstPtr.Config.BaseAddress, 0x0C, 0x1);
  usleep(10);
  XSysMon_WriteReg(SysMonInstPtr.Config.BaseAddress, 0x0C, 0x0);
  sleep(1);

  while (1) {
    Status = XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)RX_BUFFER_BASE,
                                    MAX_PKT_LEN, XAXIDMA_DEVICE_TO_DMA);
    if (Status != XST_SUCCESS) {
      xil_printf("XFER failed %d\r\n", Status);
      return XST_FAILURE;
    }
    xil_printf("busy?\r\n");

    while ((XAxiDma_Busy(&AxiDma, XAXIDMA_DEVICE_TO_DMA))) {
      /* Wait */
    }
    xil_printf("not busy anymore\r\n");

    Xil_DCacheFlushRange((UINTPTR)RxBufferPtr, MAX_PKT_LEN);
  }

  return 0;
}