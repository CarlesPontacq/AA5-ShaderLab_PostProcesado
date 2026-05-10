using UnityEngine;
using UnityEngine.InputSystem;

public class PostProcessController : MonoBehaviour
{
    [System.Serializable]
    public class Effect
    {
        public Material material;
        public string keyword;
        public Key key;
    }

    public Effect[] effects;

    void Update()
    {
        if (Keyboard.current == null)
            return;

        foreach (Effect effect in effects)
        {
            if (Keyboard.current[effect.key].wasPressedThisFrame)
            {
                ToggleEffect(effect);
            }
        }

        if (Keyboard.current.digit0Key.wasPressedThisFrame)
        {
            DisableAllEffects();
        }
    }

    private void ToggleEffect(Effect effect)
    {
        if (effect.material.IsKeywordEnabled(effect.keyword))
        {
            effect.material.DisableKeyword(effect.keyword);
            Debug.Log(effect.material.name + " OFF");
        }
        else
        {
            effect.material.EnableKeyword(effect.keyword);
            Debug.Log(effect.material.name + " ON");
        }
    }

    private void DisableAllEffects()
    {
        foreach (Effect effect in effects)
        {
            if (effect.material != null)
            {
                effect.material.DisableKeyword(effect.keyword);
            }
        }

        Debug.Log("Todos los efectos OFF");
    }
}