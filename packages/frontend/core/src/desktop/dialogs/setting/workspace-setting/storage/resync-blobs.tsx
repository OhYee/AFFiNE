import { notify } from '@affine/component';
import { SettingRow } from '@affine/component/setting-components';
import { Button } from '@affine/component/ui/button';
import { useAsyncCallback } from '@affine/core/components/hooks/affine-async-hooks';
import { WorkspaceService } from '@affine/core/modules/workspace';
import { useI18n } from '@affine/i18n';
import { useService } from '@toeverything/infra';
import { useState } from 'react';

export const ResyncBlobsPanel = () => {
  const t = useI18n();
  const workspace = useService(WorkspaceService).workspace;
  const [syncing, setSyncing] = useState(false);

  const handleResync = useAsyncCallback(async () => {
    setSyncing(true);
    try {
      await workspace.engine.blob.fullDownload();
      notify.success({
        title:
          t[
            'com.affine.settings.workspace.storage.resync-blobs.done'
          ](),
      });
    } catch (e: unknown) {
      const message =
        e instanceof Error ? e.message : 'Failed to re-sync blobs';
      notify.error({ title: message });
    } finally {
      setSyncing(false);
    }
  }, [workspace.engine.blob, t]);

  return (
    <SettingRow
      name={t['com.affine.settings.workspace.storage.resync-blobs']()}
      desc={t[
        'com.affine.settings.workspace.storage.resync-blobs.description'
      ]()}
    >
      <Button
        variant="primary"
        onClick={handleResync}
        loading={syncing}
        disabled={syncing}
      >
        {syncing
          ? t[
              'com.affine.settings.workspace.storage.resync-blobs.syncing'
            ]()
          : t[
              'com.affine.settings.workspace.storage.resync-blobs.button'
            ]()}
      </Button>
    </SettingRow>
  );
};
